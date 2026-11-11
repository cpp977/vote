from datetime import UTC, datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, model_validator


def utc_now() -> datetime:
    return datetime.now(UTC)


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Track(StrEnum):
    INTERNAL = "internal"
    ALPHA = "alpha"
    CLOSED = "closed"  # Retained for compatibility with older registry data
    OPEN = "open"
    PRODUCTION = "production"


class BuildStatus(StrEnum):
    RESERVED = "reserved"
    BUILDING = "building"
    UPLOADED = "uploaded"
    BUILD_FAILED = "build_failed"
    UPLOAD_FAILED = "upload_failed"


class TrackStatus(StrEnum):
    NOT_PROMOTED = "not_promoted"
    PENDING = "pending"
    ACTIVE = "active"
    INACTIVE = "inactive"


class PromotionAction(StrEnum):
    UPLOADED = "uploaded"
    PROMOTION_REQUESTED = "promotion_requested"
    PROMOTED = "promoted"
    PROMOTION_FAILED = "promotion_failed"


class SourceInfo(StrictModel):
    branch: str
    commit: str


class BuildInfo(StrictModel):
    status: BuildStatus = BuildStatus.RESERVED
    workflow_run_id: int | None = None
    artifact_name: str | None = None
    sha256: str | None = None


class TrackInfo(StrictModel):
    status: TrackStatus = TrackStatus.NOT_PROMOTED
    promoted_at: datetime | None = None


class HistoryEvent(StrictModel):
    action: PromotionAction
    track: Track | None = None
    from_track: Track | None = None
    to_track: Track | None = None
    timestamp: datetime = Field(default_factory=utc_now)
    details: str | None = None
    merge_commit: str | None = None


class ReleaseBuild(StrictModel):
    version_name: str
    version_code: int = Field(gt=0)
    source: SourceInfo
    created_at: datetime = Field(default_factory=utc_now)
    build: BuildInfo = Field(default_factory=BuildInfo)
    tracks: dict[str, TrackInfo] = Field(default_factory=dict)
    history: list[HistoryEvent] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_tracks(self):
        for track in self.tracks:
            if not track.strip():
                raise ValueError("Track names cannot be empty")
        return self


class ReleaseRegistry(StrictModel):
    schema_version: int = 1
    package_name: str = "com.dev.vote"
    last_allocated_version_code: int = 0
    builds: dict[int, ReleaseBuild] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_registry(self):
        for key, build in self.builds.items():
            if int(key) != build.version_code:
                raise ValueError(
                    f"Build key {key} does not match version code "
                    f"{build.version_code}"
                )

        highest = max(self.builds.keys(), default=0)
        if self.last_allocated_version_code < highest:
            raise ValueError(
                "last_allocated_version_code cannot be lower "
                "than an existing build"
            )
        return self
