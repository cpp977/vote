import json
import os
import tempfile
from pathlib import Path

from .models import ReleaseRegistry


class RegistryStore:
    def __init__(self, path: str | Path):
        self.path = Path(path)

    def load(self) -> ReleaseRegistry:
        if not self.path.exists():
            return ReleaseRegistry()

        with self.path.open("r", encoding="utf-8") as file:
            data = json.load(file)

        return ReleaseRegistry.model_validate(data)

    def save(self, registry: ReleaseRegistry) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)

        content = registry.model_dump_json(indent=2) + "\n"

        fd, temporary_path = tempfile.mkstemp(
            dir=self.path.parent,
            prefix=f".{self.path.name}.",
            suffix=".tmp",
        )

        try:
            with os.fdopen(fd, "w", encoding="utf-8") as file:
                file.write(content)
                file.flush()
                os.fsync(file.fileno())

            os.replace(temporary_path, self.path)
        except Exception:
            try:
                os.unlink(temporary_path)
            except FileNotFoundError:
                pass
            raise
