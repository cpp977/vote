# Design: user-submitted answer options for existing questions

Status: draft — awaiting review before implementation
Applies to: `vote` (Flutter frontend, this repository) and `vote-backend` (separate repository)
Related code: `lib/pages/question_detail_page.dart`, `lib/widgets/create_question_dialog.dart`,
`lib/services/submission_service.dart`, `lib/pages/my_submissions_page.dart`,
`lib/pages/admin_submissions_page.dart`, `lib/services/admin_service.dart`

> The design mirrors the established **question submission** flow end to end: a user
> files something, it enters a `pending` review queue, and an administrator approves
> or rejects it. Nothing a user submits ever goes public without an admin decision.
> The difference is the payload: a question carries text + optional category + optional
> answer options; an **answer submission** carries just an answer text (plus the
> question it belongs to, which is fixed by the endpoint).

## Summary

Today a user can only *vote* on an existing question (`POST /questions/{id}/answer`
picks one of the pre-approved answer options). There is no way for a user to propose
a **new** answer option for a question. Administrators can only add options during
question approval, before the question is public — so a question that went live with
two options is frozen at two options forever.

This feature lets any authenticated user propose a new answer option for an existing
question. The proposal follows the exact same moderation lifecycle as a question
submission:

1. the user submits the option text → stored as a **pending** answer submission,
2. an administrator reviews it in the admin queue,
3. on **approve** the text is appended to the question's `answer_options` (it becomes
   a votable choice for everyone) and the submission is marked `approved`,
4. on **reject** the submission is marked `rejected` and nothing is added.

## Goals

1. Let users enrich existing questions with new answer options — the missing half of
   the question-submission feature.
2. Reuse the question-submission moderation model as-is: `pending` / `approved` /
   `rejected`, `submitted_by`, `reviewed_by`, `reviewed_at`, one review queue, one
   set of admin screens. Users and admins learn nothing new.
3. Keep the public data model intact: `answer_options` stays the only source of
   votable choices; only admins' approvals ever create rows there.
4. Stay backwards compatible: no existing endpoint changes its request or response
   shape; old clients are unaffected.
5. Ship backend first, frontend second (see rollout).

## Non-goals

- Editing or deleting answer options after approval (the existing admin text-change
  endpoint `PATCH /admin/questions/{id}/change` stays the only way to fix a typo in
  a question; answer text changes are out of scope).
- Voting on answer submissions, "likes", or any other ranking.
- Proposing a *question* through this flow (that endpoint is untouched).
- Multiple answer options in a single submission — one submission carries exactly
  one answer text. (Multiple options remain possible by submitting several times, or
  by the admin during question approval.)
- Anonymous submissions — the submitter is always the authenticated user, exactly
  like question submissions.

## Decisions

| Topic | Decision |
| --- | --- |
| Moderation | identical to questions: `pending` → admin **approve** or **reject** |
| Storage | new table `answer_submissions`, one row per proposed option |
| Submit target | only `approved` questions can receive answer submissions |
| Payload | a single `text` (trimmed, non-empty, ≤ 500 chars); nothing else |
| Duplicates | allowed at submit time (text may match an existing option); the admin decides |
| Approve effect | the text is appended to `answer_options` and the submission is marked `approved` |
| Concurrency | approve is guarded: a submission that is not `pending` anymore → 409 |
| Who approves | admins only (`AdminAuthFilter`), same as question review |
| Who sees submissions | submitter (`GET .../mine`), admin (review queue); public read paths unchanged |
| Migration | additive only: one new table, no changes to `questions` / `answer_options` |
| Frontend reuse | new dialog + service methods + admin screen, modeled on the question equivalents |

## Contract (new endpoints)

All new endpoints require `Authorization: Bearer <token>`. Errors are
`{"error": "<message>"}` — the same envelope the client already renders verbatim.

### AnswerSubmission shape

```jsonc
{
  "id": 12,                        // answer_submissions.id
  "question_id": 7,                // the question the option is proposed for
  "question_text": "Who is going to win?",  // denormalized for list screens
  "text": "Team C",                // the proposed answer option
  "language": "en",                // copied from the question
  "submission_status": "pending",  // pending | approved | rejected
  "created_at": "2026-08-24T10:00:00Z",
  "submitted_by": "alice",         // uuid, optional
  "reviewed_by": null,             // uuid, optional
  "reviewed_at": null              // timestamp, optional
}
```

`question_text` is denormalized into the response (joined from `questions`) so that
the "My submissions" and admin screens can render the question next to the proposed
option without an extra request per row. It is read-only.

### `POST /questions/{id}/answer-submissions` — propose a new answer option

| Auth | JwtAuthFilter (any active user) |
| --- | --- |
| Body | `{ "text": "Team C" }` |
| Success | `201` + the created `AnswerSubmission` |
| Errors | `400` bad input, `401` unauthenticated, `404` question not found or not approved, `500` |

Validation order:

1. body must be a JSON object, else `400`;
2. `text` required, non-empty string after trimming, else
   `400 {"error": "Field 'text' (string, non-empty) is required"}`; longer than
   500 characters → `400 {"error": "Field 'text' must be at most 500 characters"}`;
3. question `{id}` must exist **and** have `submission_status = 'approved'`, else
   `404 {"error": "Question not found"}`;
4. submitter taken from the JWT attribute `user_id`, never from the body;
5. single `INSERT INTO answer_submissions (...) VALUES (..., 'pending', $user) RETURNING …`
   → `201`.

Duplicates (same text already on the question, or another pending submission with the
same text) are **accepted**; the admin screen shows the question's current options so
the reviewer can reject a duplicate. This keeps the submit path free of surprising
errors and matches the question flow, which also never de-duplicates.

```http
POST /questions/7/answer-submissions
Authorization: Bearer <token>
Content-Type: application/json

{ "text": "Team C" }
```

```json
HTTP/1.1 201 Created
{
  "id": 12,
  "question_id": 7,
  "question_text": "Who is going to win?",
  "text": "Team C",
  "language": "en",
  "submission_status": "pending",
  "created_at": "2026-08-24T10:00:00Z",
  "submitted_by": "6f1c…",
  "reviewed_by": null,
  "reviewed_at": null
}
```

### `GET /answer-submissions/mine` — the submitter's own answer submissions

| Auth | JwtAuthFilter |
| --- | --- |
| Query | `?status=pending|rejected|approved` (optional; default: all) |
| Success | `200` + array of `AnswerSubmission`, newest first |

Scoped with `WHERE submitted_by = <user_id>` — same as `GET /questions/mine`.

### `GET /admin/answer-submissions` — review queue

| Auth | AdminAuthFilter |
| --- | --- |
| Query | `?status=pending|rejected` (optional; default: everything not approved) |
| Success | `200` + array of `AnswerSubmission`, newest first |

Mirrors `GET /admin/questions/submissions`.

### `POST /admin/answer-submissions/{id}/approve`

| Auth | AdminAuthFilter |
| --- | --- |
| Body | `{}` (empty; accepted for symmetry with the question approve) |
| Success | `200` + the updated `AnswerSubmission` |
| Errors | `400` malformed body, `403` non-admin, `404` unknown id, `409` already reviewed, `500` |

One transaction:

1. `SELECT … FROM answer_submissions WHERE id = $1 FOR UPDATE` — missing → `404`;
2. `submission_status <> 'pending'` → `409 {"error": "the submission has already been reviewed"}`
   (same message as the question approve);
3. `INSERT INTO answer_options (question_id, text) SELECT question_id, text
   FROM answer_submissions WHERE id = $1` — the option is appended;
4. `UPDATE answer_submissions SET submission_status = 'approved', reviewed_by = $admin,
   reviewed_at = NOW() WHERE id = $1`.

The question itself is not touched: an answer submission is only possible on an
already-approved question, so the question's own review state never changes.

### `POST /admin/answer-submissions/{id}/reject`

| Auth | AdminAuthFilter |
| --- | --- |
| Body | `{}` (empty; a rejection *reason* is deliberately not collected — same as question reject) |
| Success | `200` + the updated `AnswerSubmission` (status `rejected`) |
| Errors | as approve |

Same transaction shape, but step 3 is replaced by
`UPDATE answer_submissions SET submission_status = 'rejected', reviewed_by = $admin,
reviewed_at = NOW()` and nothing is inserted into `answer_options`.

## Database migration

Additive only — one new migration `000007_answer_submissions.up.sql` / `.down.sql`,
following the golang-migrate conventions in the backend `AGENTS.md`:

```sql
-- up
CREATE TABLE answer_submissions (
    id                BIGSERIAL PRIMARY KEY,
    question_id       BIGINT NOT NULL
        REFERENCES questions(id) ON DELETE CASCADE,
    text              TEXT NOT NULL,
    submission_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (submission_status IN ('pending', 'approved', 'rejected')),
    submitted_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_by       UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at       TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_answer_submissions_status ON answer_submissions (submission_status);
CREATE INDEX ix_answer_submissions_question ON answer_submissions (question_id);
CREATE INDEX ix_answer_submissions_submitted_by ON answer_submissions (submitted_by);

-- down
DROP TABLE answer_submissions;
```

No change to `questions`, `answer_options`, `user_answers` or `question_user`.
The FK to `questions` uses `ON DELETE CASCADE` (like `answer_options`), so deleting a
question takes its pending submissions with it — no orphan review rows.

### Maintenance: purging rejected submissions

Rejected content is kept for a retention period (30 days by default) and then
deleted by the existing database maintenance job — the systemd user timer driven by
`ansible/roles/db-maintenance` that already purges rejected **questions**
(`DELETE FROM questions WHERE submission_status = 'rejected' AND reviewed_at < now() -
interval 'N days'`). Answer submissions get the mirror task:

- new inventory variable `vote_backend_rejected_answer_submissions_retention_days`
  (default `30`, next to `vote_backend_rejected_questions_retention_days`), exported
  into the maintenance env file as `DB_MAINTENANCE_ANSWER_RETENTION_DAYS`;
- a second `run_task "cleanup_rejected_answer_submissions"` in the maintenance script:
  `DELETE FROM answer_submissions WHERE submission_status = 'rejected' AND
  reviewed_at < now() - interval '${DB_MAINTENANCE_ANSWER_RETENTION_DAYS} days';`
- the `db-migrate` role grants the maintenance role `SELECT, DELETE` on
  `answer_submissions` (it already does for `questions`), because the table only
  exists after the migrations ran.

The tasks stay independent: one failing delete does not block the other, same as today.

## Backend implementation plan

All changes in `vote-backend`:

1. **Migration** `migrations/000007_answer_submissions.{up,down}.sql` as above. The
   migration role owns the new table automatically (it runs the DDL).
2. **`QuestionController`** (route table + new methods, following the exact patterns
   of `submitQuestion` / `getMySubmissions` / `listSubmissions` / `approveQuestion`):
   - `POST   /questions/{1}/answer-submissions`      → `submitAnswerOption`   (JwtAuthFilter)
   - `GET    /answer-submissions/mine`               → `getMyAnswerSubmissions` (JwtAuthFilter)
   - `GET    /admin/answer-submissions`              → `listAnswerSubmissions`  (AdminAuthFilter)
   - `POST   /admin/answer-submissions/{1}/approve`   → `approveAnswerSubmission`(AdminAuthFilter)
   - `POST   /admin/answer-submissions/{1}/reject`    → `rejectAnswerSubmission` (AdminAuthFilter)
   - a `answerSubmissionToJson(const drogon::orm::Row&)` serializer next to
     `questionToJson`, and the queries join `questions` for `question_text` / `language`.
3. **Validation helpers**: reuse the `trimText` helper; `text` length capped at 500.
4. **`API_DOCUMENTATION.md`**: five new rows in the endpoint table.
5. **Maintenance job** (`ansible/roles/db-maintenance` + `db-migrate` grant): the
   rejected-answer-submission cleanup task described above.
6. **Integration tests** (`tests/integration/test_endpoints.cpp`) mirroring the
   `SubmissionWorkflow …` cases:
   - submit → 201 pending, visible in `/mine` and the admin queue;
   - submit to a pending/unknown question → 404; submit without text → 400;
   - non-admin approve → 403; admin approve → 200, option now votable via
     `POST /questions/{id}/answer` and listed by `GET /questions/{id}/answers`;
   - second approve → 409; reject → 200 rejected, no option added.

## Frontend implementation plan

All changes in `vote` (this repository). The UI pattern is the question-submission
dialog, reduced to a single field, plus two list surfaces that already exist for
questions.

1. **Models** (`lib/models/submission_models.dart` or a new `answer_submission_models.dart`):
   `AnswerSubmission` with `id, questionId, questionText, text, language,
   submissionStatus, createdAt, submittedBy, reviewedBy` + `fromJson` + status getters
   (`isPending` / `isApproved` / `isRejected`).
2. **Service** (`lib/services/submission_service.dart`):
   - `submitAnswerOption({required int questionId, required String text})` →
     `POST /questions/{id}/answer-submissions`, `201` → `AnswerSubmission`;
   - `getMyAnswerSubmissions({String? status})` → `GET /answer-submissions/mine`.
   `AdminService` gains `listAnswerSubmissions({String? status})`,
   `approveAnswerSubmission(id)`, `rejectAnswerSubmission(id)`.
3. **Submit UI** — on the question detail page (`lib/pages/question_detail_page.dart`):
   a new `TextButton.icon` (`Icons.add_comment_outlined`, label `l10n.suggestAnswer`)
   in the "Possible answers" header row (next to the existing Delete-Answer button,
   shown to any authenticated user). It opens `showSuggestAnswerDialog(...)`
   (`lib/widgets/suggest_answer_dialog.dart`): one optional multi-line `TextFormField`
   (label `l10n.suggestedAnswerLabel`, hint `l10n.suggestedAnswerHint`), the question
   text shown read-only at the top, inline error box, Cancel / Submit buttons.
   Success → green snackbar `l10n.answerSubmissionCreated` ("Answer suggestion
   submitted for review"), `onQuestionUpdated?.call()` is **not** needed (the option
   only appears after approval) but the dialog closes; 401 → logout/login like the
   question dialog.
   Guest gate: unauthenticated users are prompted to sign in first, same
   `_promptSignIn` flow as `SubmitQuestionButton`.
4. **My submissions** (`lib/pages/my_submissions_page.dart`): add a second section
   below the question submissions listing the user's answer submissions
   (`AnswerSubmission` rows: question text + proposed text + status chip), reusing
   the existing status-chip widgets and `submissionPending/Approved/Rejected` strings.
5. **Admin** (`lib/pages/admin_submissions_page.dart` + `lib/services/admin_service.dart`):
   add a second tab/section "Answer suggestions" listing the review queue with
   Approve / Reject actions calling the new admin endpoints; each row shows the
   question text, the proposed option and the submitter. Follow the existing
   `admin_submission_detail_page.dart` review flow (approve button, reject with the
   existing confirmation, backend `error` shown verbatim).
6. **l10n**: new keys in `lib/l10n/app_en.arb` (+ German in `app_de.arb`), e.g.
   `suggestAnswer`, `suggestedAnswerLabel`, `suggestedAnswerHint`,
   `answerSubmissionCreated`, `answerSubmissionFailed`, `answerSubmissions`,
   `adminAnswerSubmissions`, `answerSubmissionPending/Approved/Rejected`,
   `approveAnswerSuggestion`, `rejectAnswerSuggestion`.
7. **Tests**: `test/services/submission_service_test.dart` (wire format + 201/400/401
   parsing), `test/widgets/suggest_answer_dialog_test.dart` (validation, success
   snackbar, error display, guest gate), plus admin-service tests for the three new
   admin calls.

## Frontend status

The client side of this design is implemented in this repository and expects the
backend contract above.

| File | Behaviour |
| --- | --- |
| `lib/models/submission_models.dart` | `AnswerSubmission` with `fromJson` and `isPending`/`isApproved`/`isRejected` |
| `lib/services/submission_service.dart` | `submitAnswerOption({questionId, text})` posts the trimmed text to `POST /questions/{id}/answer-submissions`; `getMyAnswerSubmissions({status})` reads `GET /answer-submissions/mine` |
| `lib/services/admin_service.dart` | `getAnswerSubmissions({status})`, `approveAnswerSubmission(id)`, `rejectAnswerSubmission(id)` |
| `lib/widgets/suggest_answer_dialog.dart` | single-field dialog (`Your answer`), question shown read-only, backend `error` shown verbatim, 401 → logout/login |
| `lib/pages/question_detail_page.dart` | "Suggest an answer" button below the answer list, with the guest sign-in prompt |
| `lib/pages/my_submissions_page.dart` | second "Answer suggestions" section listing the user's own answer submissions with status chips |
| `lib/pages/admin_submissions_page.dart` | second tab "Answer Suggestions" in the review queue with Approve / Reject (reject asks for confirmation), backend `error` shown verbatim |
| `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb` | all new strings in English and German |
| `lib/widgets/intro_carousel.dart`, `lib/services/tutorial_controller.dart`, `lib/main.dart` | fifth introduction page ("Suggest Answers", `sinceRevision: 2`) plus revision tracking: the tour is shown again once when its content changes, and returning users start at the first page they have not seen (`initialPage`) instead of the beginning |

## Compatibility and rollout

| Combination | Result |
| --- | --- |
| new backend + old client | unchanged — no existing endpoint is touched |
| new backend + new client | full feature |
| old backend + new client | `POST /questions/{id}/answer-submissions` → `404` route-not-found; the dialog shows the raw error and degrades gracefully. Do not ship in this order. |

Rollout:

1. Deploy the backend (migration + five endpoints + docs). Existing clients are
   unaffected; nothing changes for them.
2. Sanity-check with curl: submit → pending in `/admin/answer-submissions` → approve →
   option appears in `GET /questions/{id}/answers` and is votable.
3. Release the frontend.

## Acceptance criteria

Backend:

1. `POST /questions/{id}/answer-submissions` with `{"text": "Team C"}` on an approved
   question returns `201` with `submission_status: "pending"`.
2. Submitting without `text`, or with a blank/`>500`-char text, returns `400`.
3. Submitting to a non-existent or non-approved question returns `404`.
4. `GET /answer-submissions/mine` returns only the caller's submissions; `?status=pending`
   filters.
5. `GET /admin/answer-submissions` requires admin (403 otherwise) and returns the queue.
6. `POST /admin/answer-submissions/{id}/approve` as admin returns `200` with status
   `approved`, the text now appears in `GET /questions/{id}/answers`, and a user can
   vote for it via `POST /questions/{id}/answer` (201).
7. Approving an already-reviewed submission returns `409`.
8. `POST /admin/answer-submissions/{id}/reject` returns `200` with status `rejected`
   and the option is **not** added.
9. Unauthenticated access to any new endpoint returns `401`.

Frontend:

10. An authenticated user can open the suggest-answer dialog from a question's detail
    page, submit a suggestion, and sees the success snackbar.
11. The suggestion appears in "My submissions" with status "pending".
12. An admin sees the suggestion in the admin review queue and can approve/reject it;
    after approval the option appears on the question detail page.
13. All new strings exist in English and German.

## Risks and open items

- **Dilution of votable options.** Unrestricted submissions could let a group flood a
  question with variants. The admin review queue is the mitigation — same trust model
  as questions, which are also unrestricted. If abuse appears, a per-question pending
  cap or a rate limit can be added later without a schema change.
- **Duplicate options.** Two users may propose the same text. The admin rejects the
  second; alternatively the approve step could `WHERE NOT EXISTS` the same text on the
  question and turn a duplicate into a no-op approval — decide during implementation
  based on what keeps the review UX simplest.
- **500-char cap** is a guess; the question text has no server-side cap (DB `TEXT`).
  Adjust if real submissions need more.
- **Not covered here**: editing a pending submission before review, rejection reasons,
  and notifications. All are out of scope, like their question-side counterparts.