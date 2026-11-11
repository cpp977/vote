"""Command-line interface for the Android release registry."""

import argparse
import json
import subprocess
import sys
from pathlib import Path

from .git_store import GitRegistryStore
from .models import BuildStatus
from .operations import (
    allocate,
    get_build,
    record_build,
    record_promotion,
    request_promotion,
)
from .registry import RegistryStore


def create_parser():
    parser = argparse.ArgumentParser(
        description="Android Google Play release registry"
    )

    parser.add_argument(
        "--store",
        choices=("local", "git"),
        default="local",
        help="Use local JSON storage or the Git-backed registry",
    )
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--registry-branch", default="release-registry")
    parser.add_argument("--registry-path", default="registry.json")

    subparsers = parser.add_subparsers(
        dest="command",
        required=True,
    )

    allocate_parser = subparsers.add_parser("allocate")
    allocate_parser.add_argument("--version-name", required=True)
    allocate_parser.add_argument("--branch", required=True)
    allocate_parser.add_argument("--commit", required=True)

    build_parser = subparsers.add_parser("record-build")
    build_parser.add_argument("--version-code", type=int, required=True)
    build_parser.add_argument(
        "--status",
        choices=[status.value for status in BuildStatus],
        required=True,
    )
    build_parser.add_argument("--workflow-run-id", type=int)
    build_parser.add_argument("--artifact-name")
    build_parser.add_argument("--sha256")

    merge_parser = subparsers.add_parser("find-merge-build")
    merge_parser.add_argument("--merge-commit", required=True)

    promote_parser = subparsers.add_parser("request-promotion")
    promote_parser.add_argument("--version-code", type=int, required=True)
    promote_parser.add_argument("--from-track", required=True)
    promote_parser.add_argument("--to-track", required=True)

    result_parser = subparsers.add_parser("record-promotion")
    result_parser.add_argument("--version-code", type=int, required=True)
    result_parser.add_argument("--from-track", required=True)
    result_parser.add_argument("--to-track", required=True)
    result_parser.add_argument(
        "--success",
        action=argparse.BooleanOptionalAction,
        required=True,
    )
    result_parser.add_argument("--details")
    result_parser.add_argument("--merge-commit")

    get_parser = subparsers.add_parser("get")
    get_parser.add_argument("--version-code", type=int, required=True)

    # Google Play API commands.
    # These commands use PLAY_SERVICE_ACCOUNT_JSON from the environment.
    play_promote_parser = subparsers.add_parser(
        "promote",
        help="Promote an existing uploaded version to a Google Play track",
    )
    play_promote_parser.add_argument(
        "--package-name",
        default="com.dev.vote",
    )
    play_promote_parser.add_argument("--track", required=True)
    play_promote_parser.add_argument("--version-code", type=int, required=True)
    play_promote_parser.add_argument("--release-name")

    monitor_parser = subparsers.add_parser(
        "monitor-promotion",
        help="Monitor a Google Play release until its lifecycle changes",
    )
    monitor_parser.add_argument(
        "--package-name",
        default="com.dev.vote",
    )
    monitor_parser.add_argument("--track", required=True)
    monitor_parser.add_argument("--version-code", type=int, required=True)
    monitor_parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=21600,
        help="Maximum time to wait (default: 6 hours)",
    )
    monitor_parser.add_argument(
        "--poll-interval-seconds",
        type=int,
        default=120,
        help="Delay between lifecycle checks (default: 120 seconds)",
    )

    state_parser = subparsers.add_parser(
        "get-release-state",
        help="Get the Google Play lifecycle state of a version",
    )
    state_parser.add_argument(
        "--package-name",
        default="com.dev.vote",
    )
    state_parser.add_argument("--track", required=True)
    state_parser.add_argument("--version-code", type=int, required=True)

    return parser


def find_merge_build(registry, repository_root, merge_commit):
    """Find the newest uploaded build included in a two-parent merge."""

    def git(*args):
        result = subprocess.run(
            ["git", *args],
            cwd=repository_root,
            text=True,
            capture_output=True,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip())
        return result.stdout.strip()

    parents = git(
        "show",
        "-s",
        "--format=%P",
        merge_commit,
    ).split()

    if len(parents) != 2:
        raise ValueError(
            f"{merge_commit} is not a two-parent merge commit"
        )

    commits = set(
        git(
            "rev-list",
            f"{parents[0]}..{parents[1]}",
        ).splitlines()
    )

    candidates = [
        build
        for build in registry.builds.values()
        if build.source.commit in commits
        and build.build.status == BuildStatus.UPLOADED
    ]

    if not candidates:
        raise ValueError(
            "No successfully uploaded build was found among the "
            "commits introduced by this merge"
        )

    candidates.sort(
        key=lambda build: build.version_code,
        reverse=True,
    )

    return candidates[0]


def print_result(result):
    """Print either a Pydantic model or a JSON-compatible result."""
    if hasattr(result, "model_dump_json"):
        print(result.model_dump_json(indent=2))
    else:
        print(json.dumps(result, indent=2, default=str))


def run_google_play_command(args):
    """Execute a Google Play API command.

    Imports are deliberately lazy so registry-only commands do not require
    Google Play API authentication or client initialization.
    """
    from .google_play import (
        create_service,
        get_release_state,
        monitor_promotion,
        promote,
    )

    service = create_service()

    if args.command == "promote":
        result = promote(
            service=service,
            package_name=args.package_name,
            track=args.track,
            version_code=args.version_code,
            release_name=args.release_name,
        )

    elif args.command == "monitor-promotion":
        result = monitor_promotion(
            service=service,
            package_name=args.package_name,
            track=args.track,
            version_code=args.version_code,
            timeout_seconds=args.timeout_seconds,
            poll_interval_seconds=args.poll_interval_seconds,
        )

    elif args.command == "get-release-state":
        result = get_release_state(
            service=service,
            package_name=args.package_name,
            track=args.track,
            version_code=args.version_code,
        )

    else:
        raise ValueError(
            f"Unsupported Google Play command: {args.command}"
        )

    print_result(result)


def main():
    parser = create_parser()
    args = parser.parse_args()

    google_play_commands = {
        "promote",
        "monitor-promotion",
        "get-release-state",
    }

    if args.command in google_play_commands:
        try:
            run_google_play_command(args)
        except Exception as exc:
            print(
                f"Google Play command failed: {exc}",
                file=sys.stderr,
            )
            raise SystemExit(1) from exc
        return

    if args.store == "git":
        store = GitRegistryStore(
            repository_root=args.repo_root,
            branch=args.registry_branch,
            registry_path=args.registry_path,
        )
    else:
        local_path = Path(args.registry_path)
        if not local_path.is_absolute():
            local_path = Path(args.repo_root) / local_path
        store = RegistryStore(local_path)

    def update(operation):
        if isinstance(store, GitRegistryStore):
            return store.update(operation)

        registry = store.load()
        result = operation(registry)
        store.save(registry)
        return result

    if args.command == "allocate":
        result = update(
            lambda registry: allocate(
                registry,
                version_name=args.version_name,
                branch=args.branch,
                commit=args.commit,
            )
        )

    elif args.command == "record-build":
        result = update(
            lambda registry: record_build(
                registry,
                version_code=args.version_code,
                status=BuildStatus(args.status),
                workflow_run_id=args.workflow_run_id,
                artifact_name=args.artifact_name,
                sha256=args.sha256,
            )
        )

    elif args.command == "find-merge-build":
        registry = store.load()
        result = find_merge_build(
            registry,
            args.repo_root,
            args.merge_commit,
        )

    elif args.command == "request-promotion":
        result = update(
            lambda registry: request_promotion(
                registry,
                version_code=args.version_code,
                from_track=args.from_track,
                to_track=args.to_track,
            )
        )

    elif args.command == "record-promotion":
        result = update(
            lambda registry: record_promotion(
                registry,
                version_code=args.version_code,
                from_track=args.from_track,
                to_track=args.to_track,
                success=args.success,
                details=args.details,
                merge_commit=args.merge_commit,
            )
        )

    elif args.command == "get":
        registry = store.load()
        result = get_build(registry, args.version_code)

    else:
        parser.error(f"Unknown command: {args.command}")

    print_result(result)


if __name__ == "__main__":
    main()
