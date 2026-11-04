from .models import (
    BuildInfo,
    BuildStatus,
    HistoryEvent,
    PromotionAction,
    ReleaseBuild,
    ReleaseRegistry,
    SourceInfo,
    Track,
    TrackInfo,
    TrackStatus,
    utc_now,
)


def allocate(
    registry: ReleaseRegistry,
    version_name: str,
    branch: str,
    commit: str,
) -> ReleaseBuild:
    """Reserve a version code. Reserved codes are never reused."""

    registry.last_allocated_version_code += 1
    version_code = registry.last_allocated_version_code

    build = ReleaseBuild(
        version_name=version_name,
        version_code=version_code,
        source=SourceInfo(branch=branch, commit=commit),
        tracks={
            Track.INTERNAL.value: TrackInfo(
                status=TrackStatus.PENDING
            )
        },
    )

    registry.builds[version_code] = build
    return build


def record_build(
    registry: ReleaseRegistry,
    version_code: int,
    status: BuildStatus,
    workflow_run_id: int | None = None,
    artifact_name: str | None = None,
    sha256: str | None = None,
) -> ReleaseBuild:
    build = get_build(registry, version_code)

    build.build.status = status
    build.build.workflow_run_id = workflow_run_id
    build.build.artifact_name = artifact_name
    build.build.sha256 = sha256

    if status == BuildStatus.UPLOADED:
        build.tracks[Track.INTERNAL.value] = TrackInfo(
            status=TrackStatus.ACTIVE,
            promoted_at=utc_now(),
        )
        build.history.append(
            HistoryEvent(
                action=PromotionAction.UPLOADED,
                track=Track.INTERNAL,
            )
        )

    return build


def request_promotion(
    registry: ReleaseRegistry,
    version_code: int,
    from_track: str,
    to_track: str,
) -> ReleaseBuild:
    build = get_build(registry, version_code)

    if build.build.status != BuildStatus.UPLOADED:
        raise ValueError("Only successfully uploaded builds can be promoted")

    if from_track == to_track:
        raise ValueError("Source and destination tracks must differ")

    source = build.tracks.get(from_track)
    if source is None or source.status != TrackStatus.ACTIVE:
        raise ValueError(
            f"Build {version_code} is not active on {from_track}"
        )

    destination = build.tracks.get(to_track)
    if destination and destination.status == TrackStatus.ACTIVE:
        raise ValueError(
            f"Build {version_code} is already active on {to_track}"
        )

    build.tracks[to_track] = TrackInfo(status=TrackStatus.PENDING)
    build.history.append(
        HistoryEvent(
            action=PromotionAction.PROMOTION_REQUESTED,
            from_track=Track(from_track),
            to_track=Track(to_track),
        )
    )

    return build


def record_promotion(
    registry: ReleaseRegistry,
    version_code: int,
    from_track: str,
    to_track: str,
    success: bool,
    details: str | None = None,
    merge_commit: str | None = None,
) -> ReleaseBuild:
    """Record the result after the Google Play operation completes."""

    build = get_build(registry, version_code)

    if to_track not in build.tracks:
        raise ValueError("Promotion was not requested")

    if build.tracks[to_track].status != TrackStatus.PENDING:
        raise ValueError("Destination track is not pending")

    if success:
        # Keep the source active. Google Play track state is independent;
        # only mark it inactive if an explicit reconciliation confirms that.
        build.tracks[to_track] = TrackInfo(
            status=TrackStatus.ACTIVE,
            promoted_at=utc_now(),
        )
        action = PromotionAction.PROMOTED
    else:
        build.tracks[to_track] = TrackInfo(
            status=TrackStatus.NOT_PROMOTED
        )
        action = PromotionAction.PROMOTION_FAILED

    build.history.append(
        HistoryEvent(
            action=action,
            from_track=Track(from_track),
            to_track=Track(to_track),
            details=details,
            merge_commit=merge_commit,
        )
    )

    return build


def get_build(
    registry: ReleaseRegistry,
    version_code: int,
) -> ReleaseBuild:
    try:
        return registry.builds[version_code]
    except KeyError:
        raise ValueError(
            f"Unknown version code: {version_code}"
        ) from None
