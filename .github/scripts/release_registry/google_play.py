"""Google Play Developer API operations for release promotion."""

from __future__ import annotations

import json
import os
import time
from typing import Any

from google.oauth2 import service_account
from googleapiclient.discovery import build

SCOPE = "https://www.googleapis.com/auth/androidpublisher"

DRAFT = "RELEASE_LIFECYCLE_STATE_DRAFT"
NOT_SENT_FOR_REVIEW = "RELEASE_LIFECYCLE_STATE_NOT_SENT_FOR_REVIEW"
IN_REVIEW = "RELEASE_LIFECYCLE_STATE_IN_REVIEW"
APPROVED_NOT_PUBLISHED = "RELEASE_LIFECYCLE_STATE_APPROVED_NOT_PUBLISHED"
NOT_APPROVED = "RELEASE_LIFECYCLE_STATE_NOT_APPROVED"
PUBLISHED = "RELEASE_LIFECYCLE_STATE_PUBLISHED"

MANUAL_ACTION_STATES = {
    DRAFT,
    NOT_SENT_FOR_REVIEW,
    APPROVED_NOT_PUBLISHED,
}


class GooglePlayError(RuntimeError):
    """Google Play operation failed."""


def create_service():
    """Create an authenticated Google Play Developer API client."""

    raw_credentials = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON")

    if not raw_credentials:
        raise GooglePlayError(
            "PLAY_SERVICE_ACCOUNT_JSON environment variable is missing"
        )

    try:
        credentials_info = json.loads(raw_credentials)
    except json.JSONDecodeError as exc:
        raise GooglePlayError(
            "PLAY_SERVICE_ACCOUNT_JSON contains invalid JSON"
        ) from exc

    credentials = service_account.Credentials.from_service_account_info(
        credentials_info,
        scopes=[SCOPE],
    )

    return build(
        "androidpublisher",
        "v3",
        credentials=credentials,
        cache_discovery=False,
    )


def _list_track_releases(
    service,
    package_name: str,
    track: str,
) -> list[dict[str, Any]]:
    """List releases and their lifecycle states for a track."""

    response = (
        service.applications()
        .tracks()
        .releases()
        .list(parent=f"applications/{package_name}/tracks/{track}")
        .execute()
    )

    return response.get("releases", [])


def get_release_state(
    service,
    package_name: str,
    track: str,
    version_code: int,
) -> dict[str, Any]:
    """Get the lifecycle state of a version code on a track."""

    releases = _list_track_releases(
        service,
        package_name,
        track,
    )

    for release in releases:
        version_codes = {
            int(artifact["versionCode"])
            for artifact in release.get("activeArtifacts", [])
            if artifact.get("versionCode") is not None
        }

        if version_code in version_codes:
            return {
                "package_name": package_name,
                "track": track,
                "version_code": version_code,
                "release_name": release.get("releaseName"),
                "lifecycle_state": release.get("releaseLifecycleState"),
            }

    return {
        "package_name": package_name,
        "track": track,
        "version_code": version_code,
        "release_name": None,
        "lifecycle_state": "NOT_FOUND",
    }


def _release_contains_version(
    release: dict[str, Any],
    version_code: int,
) -> bool:
    return version_code in {int(code) for code in release.get("versionCodes", [])}


def promote(
    service,
    package_name: str,
    track: str,
    version_code: int,
    release_name: str | None = None,
) -> dict[str, Any]:
    """Promote an existing uploaded artifact to a Google Play track.

    This operation:
      1. Checks whether the version is already published or under review.
      2. Refuses to interfere with another unfinished release.
      3. Creates an edit.
      4. Preserves non-completed release configurations.
      5. Replaces the previous completed release with the requested version.
      6. Commits the edit and submits changes for review.

    It does not upload a new artifact or allocate a version code.
    """

    if version_code <= 0:
        raise ValueError("version_code must be greater than zero")

    # Check the current state first. This makes workflow retries safer.
    current_state = get_release_state(
        service,
        package_name,
        track,
        version_code,
    )

    lifecycle = current_state["lifecycle_state"]

    if lifecycle == PUBLISHED:
        return {
            "action": "already_published",
            **current_state,
        }

    if lifecycle == IN_REVIEW:
        return {
            "action": "already_in_review",
            **current_state,
        }

    if lifecycle in MANUAL_ACTION_STATES:
        raise GooglePlayError(
            f"Version {version_code} is in state {lifecycle}. "
            "Manual action in Google Play Console is required."
        )

    if lifecycle == NOT_APPROVED:
        raise GooglePlayError(
            f"Version {version_code} was rejected by Google Play. "
            "Resolve the rejection before attempting another promotion."
        )

    # Do not start another release while the track has unfinished work.
    existing_lifecycle_releases = _list_track_releases(
        service,
        package_name,
        track,
    )

    unfinished = [
        release
        for release in existing_lifecycle_releases
        if release.get("releaseLifecycleState")
        in (
            DRAFT,
            NOT_SENT_FOR_REVIEW,
            IN_REVIEW,
            APPROVED_NOT_PUBLISHED,
        )
    ]

    if unfinished:
        descriptions = [
            (
                f"{release.get('releaseName', '(unnamed)')}: "
                f"{release.get('releaseLifecycleState')}"
            )
            for release in unfinished
        ]

        raise GooglePlayError(
            "The destination track already has an unfinished release: "
            + "; ".join(descriptions)
        )

    edits = service.edits()

    edit = edits.insert(
        packageName=package_name,
        body={},
    ).execute()

    edit_id = edit["id"]
    committed = False

    try:
        # Read the current edit's track configuration.
        track_resource = (
            edits.tracks()
            .get(
                packageName=package_name,
                editId=edit_id,
                track=track,
            )
            .execute()
        )

        existing_releases = track_resource.get("releases", [])

        # Google Play allows only one completed release per track.
        # Remove the previous completed release and any existing entry
        # for the version we are promoting.
        preserved_releases = [
            release
            for release in existing_releases
            if (
                release.get("status") != "completed"
                and not _release_contains_version(release, version_code)
            )
        ]

        new_release = {
            "name": release_name or f"Build {version_code}",
            "versionCodes": [str(version_code)],
            "status": "completed",
        }

        preserved_releases.append(new_release)

        edits.tracks().update(
            packageName=package_name,
            editId=edit_id,
            track=track,
            body={
                "track": track,
                "releases": preserved_releases,
            },
        ).execute()

        # Commit directly for review. Do not cancel another review.
        edits.commit(
            packageName=package_name,
            editId=edit_id,
            changesInReviewBehavior="ERROR_IF_IN_REVIEW",
        ).execute()

        committed = True

    except Exception:
        # Delete only our uncommitted edit. Never attempt to roll back
        # an edit after Google Play has accepted the commit.
        if not committed:
            try:
                edits.delete(
                    packageName=package_name,
                    editId=edit_id,
                ).execute()
            except Exception:
                pass

        raise

    return {
        "action": "submitted",
        "package_name": package_name,
        "track": track,
        "version_code": version_code,
        "edit_id": edit_id,
        "lifecycle_state": "SUBMISSION_SENT",
    }


def monitor_promotion(
    service,
    package_name: str,
    track: str,
    version_code: int,
    timeout_seconds: int = 21600,
    poll_interval_seconds: int = 120,
) -> dict[str, Any]:
    """Wait for a release to reach a terminal or manual-action state.

    Results:
      published              - release is published
      rejected               - Google Play rejected the release
      manual_action_required - developer must act in Play Console
      timeout                - monitoring period expired
    """

    if timeout_seconds < 0:
        raise ValueError("timeout_seconds cannot be negative")

    if poll_interval_seconds < 1:
        raise ValueError("poll_interval_seconds must be at least 1")

    deadline = time.monotonic() + timeout_seconds

    while True:
        state = get_release_state(
            service,
            package_name,
            track,
            version_code,
        )

        lifecycle = state["lifecycle_state"]

        if lifecycle == PUBLISHED:
            # Do not trust a single PUBLISHED response. Google Play's
            # lifecycle state may be temporarily stale while processing.
            remaining = deadline - time.monotonic()

            if remaining <= 0:
                return {
                    **state,
                    "result": "timeout",
                }

            time.sleep(min(poll_interval_seconds, remaining))

            confirmation = get_release_state(
                service,
                package_name,
                track,
                version_code,
            )

            if confirmation["lifecycle_state"] == PUBLISHED:
                return {
                    **confirmation,
                    "result": "published",
                    "confirmed": True,
                }

            # The state changed or is not yet stable. Resume normal polling.
            continue
        if lifecycle == NOT_APPROVED:
            return {
                **state,
                "result": "rejected",
            }

        if lifecycle in MANUAL_ACTION_STATES:
            return {
                **state,
                "result": "manual_action_required",
            }

        # NOT_FOUND can occur while the release is being processed.
        # Keep polling until it appears or the timeout is reached.

        remaining = deadline - time.monotonic()

        if remaining <= 0:
            return {
                **state,
                "result": "timeout",
            }

        time.sleep(min(poll_interval_seconds, remaining))
