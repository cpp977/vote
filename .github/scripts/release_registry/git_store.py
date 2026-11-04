"""Git-backed registry with optimistic concurrency and push retries."""

from __future__ import annotations

import subprocess
import tempfile
import time
from pathlib import Path
from typing import Callable, TypeVar

from .models import ReleaseRegistry
from .registry import RegistryStore

T = TypeVar("T")


class GitRegistryStore:
    def __init__(
        self,
        repository_root: str | Path = ".",
        branch: str = "release-registry",
        registry_path: str = "registry.json",
        max_attempts: int = 10,
    ):
        self.repository_root = Path(repository_root).resolve()
        self.branch = branch
        self.registry_path = Path(registry_path)
        self.max_attempts = max_attempts

        if self.registry_path.is_absolute() or ".." in self.registry_path.parts:
            raise ValueError("registry_path must be relative to the Git worktree")

    def _git(self, *args: str, cwd: Path | None = None) -> str:
        result = subprocess.run(
            ["git", *args],
            cwd=cwd or self.repository_root,
            text=True,
            capture_output=True,
        )
        if result.returncode:
            raise RuntimeError(
                f"Git command failed: git {' '.join(args)}\n"
                f"{result.stderr.strip()}"
            )
        return result.stdout.strip()

    def load(self) -> ReleaseRegistry:
        """Read the latest committed registry from the remote branch."""
        self._git("fetch", "origin", self.branch)

        content = self._git(
            "show",
            f"refs/remotes/origin/{self.branch}:{self.registry_path.as_posix()}",
        )
        return ReleaseRegistry.model_validate_json(content)

    def update(self, operation: Callable[[ReleaseRegistry], T]) -> T:
        """Apply an operation and push it, retrying concurrent updates.

        The operation is re-executed against the latest registry after a
        push conflict. Keep operations deterministic and free of external
        side effects.
        """
        for attempt in range(1, self.max_attempts + 1):
            self._git("fetch", "origin", self.branch)

            with tempfile.TemporaryDirectory(prefix="release-registry-") as tmp:
                worktree = Path(tmp) / "worktree"

                self._git(
                    "worktree",
                    "add",
                    "--detach",
                    str(worktree),
                    f"refs/remotes/origin/{self.branch}",
                )

                try:
                    registry_file = worktree / self.registry_path
                    store = RegistryStore(registry_file)
                    registry = store.load()

                    result = operation(registry)
                    store.save(registry)

                    self._git(
                        "add",
                        "--",
                        self.registry_path.as_posix(),
                        cwd=worktree,
                    )

                    changed = subprocess.run(
                        ["git", "diff", "--cached", "--quiet"],
                        cwd=worktree,
                        capture_output=True,
                    )

                    if changed.returncode == 0:
                        return result

                    if changed.returncode != 1:
                        raise RuntimeError(
                            "Could not inspect staged registry changes"
                        )

                    self._git(
                        "-c", "user.name=Release Registry Bot",
                        "-c", "user.email=release-registry@users.noreply.github.com",
                        "commit",
                        "-m",
                        "registry: update Android release registry",
                        cwd=worktree,
                    )

                    push = subprocess.run(
                        [
                            "git",
                            "push",
                            "origin",
                            f"HEAD:refs/heads/{self.branch}",
                        ],
                        cwd=worktree,
                        text=True,
                        capture_output=True,
                    )

                    if push.returncode == 0:
                        return result

                    error = push.stderr + push.stdout
                    conflict = (
                        "non-fast-forward" in error.lower()
                        or "fetch first" in error.lower()
                        or "[rejected]" in error.lower()
                    )

                    if not conflict:
                        raise RuntimeError(
                            f"Could not push registry update:\n{error}"
                        )

                finally:
                    subprocess.run(
                        ["git", "worktree", "remove", "--force", str(worktree)],
                        cwd=self.repository_root,
                        capture_output=True,
                        text=True,
                    )

            if attempt < self.max_attempts:
                time.sleep(min(0.25 * attempt, 2.0))

        raise RuntimeError(
            f"Could not update registry after {self.max_attempts} attempts "
            "because of concurrent changes"
        )
