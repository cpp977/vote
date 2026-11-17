# Design: optional category and answer options for question submissions

Status: agreed, ready to implement (backend)
Applies to: `vote` (Flutter frontend, this repository) and the separate `vote-backend` repository
Related code: `lib/services/submission_service.dart`, `lib/widgets/create_question_dialog.dart`,
`lib/services/admin_service.dart`, `lib/pages/admin_submission_detail_page.dart`

> The backend lives in a different repository and is not available here. The contract
> below is **deduced from the client code in this repository** (see "Current contract").
> Paths, status codes and error shapes must be confirmed against the backend before
> implementation; everything else (field semantics, validation rules, rollout order) is
> a decision, not a deduction.

## Summary

Submitting a question currently forces the user to pick a category and to type at least
one answer option. Both become optional at submission time:

- a question may be filed with **no category**,
- a question may be filed with **no answer options**.

An approved question always has **exactly one category and at least two answer options**,
so whatever the submitter leaves out is completed by an administrator during approval.
Two options is the minimum for a meaningful vote, and because answers cannot be edited
after approval, a question that went public with a single option could never be repaired.

## Goals

1. Lower the barrier to submitting a question: only the question text is mandatory.
2. Keep the public data model intact: no approved question without a category, none with fewer than two answers.
3. Keep the change backwards compatible: existing clients, existing submissions and the
   current admin UI keep working unchanged.
4. Ship in two steps: backend first (relaxing validation, extending the approve payload),
   frontend second (the frontend part is already implemented in this repository).

## Non-goals

- Editing answer options of a question that already has them (an approved question's
  answers stay as submitted; use the existing admin text-change endpoint for text).
- Changing `min_age`, `special_category`, the review queue, reject, or the voting endpoints.
- A separate "uncategorized" category entity. A missing category is represented as
  `NULL` and rendered as "Uncategorized" by the client.

## Decisions

| Topic | Decision |
| --- | --- |
| Category at submission | optional, stored as `NULL` |
| Answer options at submission | optional, zero options allowed |
| Category at approval | mandatory — approve fails if the question would go public without one |
| Answer options at approval | at least **two** — approve fails if the question would go public with fewer |
| Answer options at approval | appended, never replaced — a submission that arrived with one option is topped up to two |
| Public read paths | unchanged; an approved question is never in the incomplete state |

## Current contract (deduced)

Taken from how the client calls the API today. "Source" points at the code that pins the
behaviour down.

| Endpoint | Request | Response | Source |
| --- | --- | --- | --- |
| `POST /questions/submissions` | `{text, category_id, language, answer_options[1..50]}` | `201` + `Submission` | `submission_service.dart` |
| `GET /questions/mine` | – | `[Submission]` (no `answer_options`) | `submission_service.dart` |
| `GET /admin/questions/submissions` | – | `[Submission]` | `admin_service.dart` |
| `GET /admin/questions/{id}/answers` | – | `[AnswerOption]`, `404` while the submission is pending | `admin_submission_detail_page.dart` |
| `POST /admin/questions/{id}/approve` | `{min_age?, special_category?}` | `200` + `Submission` | `admin_service.dart` |
| `POST /admin/questions/{id}/reject` | – | `200` + `Submission` | `admin_service.dart` |
| `GET /questions/restSearch`, `/questions/restSearch-with-auth` | `{language, offset, limit, search?, categoryIds?, unanswered_only?, age?}` | `[Question]` with `category_id`, `category_name`, `special_category`, `answered` | `home_page.dart` |
| `GET /questions/{id}/answers`, `POST /questions/{id}/answer`, `DELETE /questions/{id}/answer` | – | answer rows / vote mutation | `question_detail_page.dart` |
| `GET /questions/{id}/stats` | – | `{status, answers[]}` | `question_stats_service.dart` |
| `GET /categories/lang/{languageCode}` | – | `[Category]` | `auth_service.dart` |

Shared shapes:

```jsonc
// Submission
{
  "id": 7,
  "text": "Who is going to win?",
  "category_id": 3,              // today: always an int
  "language": "en",
  "min_age": 0,
  "created_at": "2026-08-24T10:00:00Z",
  "submission_status": "pending", // pending | approved | rejected
  "submitted_by": "alice",        // optional
  "reviewed_by": null,            // optional
  "answer_options": [             // only in the POST response
    { "id": 1, "question_id": 7, "text": "Team A" }
  ]
}
```

Errors are returned as `{"error": "<message>"}`; the client surfaces that message verbatim
(`AdminService._parseError`, `SubmissionService._parseError`) and falls back to the raw body
when the field is missing.

## Backend changes

### 1. `POST /questions/submissions` — relax validation

| Field | Before | After |
| --- | --- | --- |
| `text` | required, non-empty | unchanged |
| `language` | required (`en`/`de`) | unchanged |
| `category_id` | required, must exist | **optional**; absent or `null` stores `NULL`; when present it must still exist and match `language` |
| `answer_options` | required, 1–50 entries | **optional**; absent or `[]` stores no answers; when present: trim, drop blank entries, deduplicate, cap at 50 |

Status codes: `201` on success (unchanged), `400` + `{"error": …}` for a bad category or too
many options, `401` when unauthenticated (unchanged).

The insert of the question plus its answer options stays in one transaction.

```http
POST /questions/submissions
Authorization: Bearer <token>
Content-Type: application/json

{ "text": "Who is going to win?", "language": "en" }
```

```json
HTTP/1.1 201 Created
{
  "id": 7,
  "text": "Who is going to win?",
  "category_id": null,
  "language": "en",
  "min_age": 0,
  "created_at": "2026-08-24T10:00:00Z",
  "submission_status": "pending",
  "submitted_by": "alice",
  "answer_options": []
}
```

### 2. `POST /admin/questions/{id}/approve` — complete what is missing

The body gains two optional fields; existing fields are unchanged.

| Field | Type | Meaning |
| --- | --- | --- |
| `min_age` | int, 0–120, default `0` | unchanged |
| `special_category` | enum label, default `none` | unchanged |
| `category_id` | int, optional | category assigned during approval; overrides the category stored on the submission |
| `answer_options` | string[], optional | answers added during approval; appended to the ones the submitter provided, and only accepted while the question has fewer than two |

Validation, evaluated in this order:

1. the submission must still be `pending` → otherwise `409` (existing behaviour);
2. `category := body.category_id ?? submission.category_id`; if still `null` → `400`
   `{"error": "a category is required to approve a question"}`;
3. `category_id`, when present, must reference an existing category → otherwise `400`;
4. if the question already has two or more answer options, a non-empty `answer_options`
   → `409` `{"error": "the question already has answer options"}` (the submitter's options
   are never replaced);
5. the question must end up with at least two options — `existing + answer_options`,
   after trimming and dropping blanks — otherwise `400`
   `{"error": "at least two answer options are required to approve a question"}`;
6. `min_age` / `special_category` are stored as today.

`answer_options` are appended to the options the submitter provided, so a submission that
arrived with a single option is completed rather than rejected.

The category assignment, the answer insert and the status change happen in one transaction.
Response: `200` + the updated `Submission`, including `answer_options` (the ones already
stored followed by the ones just added) so the admin UI can refresh from a single call.

```http
POST /admin/questions/7/approve
Authorization: Bearer <admin token>
Content-Type: application/json

{ "min_age": 16, "special_category": "none", "category_id": 3, "answer_options": ["Team A", "Team B"] }
```

```json
HTTP/1.1 200 OK
{
  "id": 7,
  "text": "Who is going to win?",
  "category_id": 3,
  "language": "en",
  "min_age": 16,
  "created_at": "2026-08-24T10:00:00Z",
  "submission_status": "approved",
  "submitted_by": "alice",
  "reviewed_by": "bob",
  "answer_options": [
    { "id": 1, "question_id": 7, "text": "Team A" },
    { "id": 2, "question_id": 7, "text": "Team B" }
  ]
}
```

### 3. Persistence

- `questions.category_id` becomes nullable; keep the foreign key.
  PostgreSQL example: `ALTER TABLE questions ALTER COLUMN category_id DROP NOT NULL;`
  (adjust to the actual schema and migration tooling).
- No new tables and no new columns. `answers` simply has zero rows for a submission
  that was filed without options.
- Existing rows are unaffected: every approved question already satisfies the invariant.
- Optional hardening: `CHECK (status <> 'approved' OR category_id IS NOT NULL)` on
  `questions`. "At least one answer" cannot be expressed as a simple check and stays a
  service-layer rule.

### 4. Read paths

| Endpoint | Change |
| --- | --- |
| `GET /questions/restSearch*` | `category_id` may be `null` and `category_name` should then be `null` or omitted; `categoryIds` filtering simply excludes such rows. No behaviour change for complete questions. |
| `GET /questions/{id}/answers` | unchanged; returns `[]` for a question without options |
| `GET /questions/{id}/stats` | unchanged; returns an empty series for a question without votes |
| `POST`/`DELETE /questions/{id}/answer` | unchanged |
| `GET /questions/mine`, `GET /admin/questions/submissions` | unchanged; `category_id` may be `null` |
| `unanswered_only` filter | unchanged — an approved question always has answers, so every listed question can be voted on |

Because approval is the only path to `approved`, the public question list never contains a
question without a category or without answers.

## Compatibility and rollout

| Combination | Result |
| --- | --- |
| new backend + old client | unchanged: the old client always sends `category_id` and a non-empty `answer_options` |
| new backend + new client | full feature: submissions may be incomplete, admins complete them during approval |
| old backend + new client | the request without `category_id`/`answer_options` is rejected with `400` + `{"error": …}`; the dialog shows that message, so the app degrades gracefully. Do not ship in this order. |

Rollout:

1. Deploy the backend change (relaxed submission validation, extended approve payload,
   nullable column). Nothing else changes for existing clients.
2. Verify with an old client that submitting with a category and answer options still works.
3. Verify that approving a submission without a category or without answers fails with `400`
   when neither field is supplied.
4. Release the frontend (already implemented here).

## Frontend status

The client side of this design is implemented in this repository and expects the backend
contract above.

| File | Behaviour |
| --- | --- |
| `lib/utils/constants.dart` | `kMaxAnswerOptions = 50` (shared by service, dialog and admin page) |
| `lib/models/submission_models.dart` | `Submission.categoryId` is `int?` |
| `lib/services/submission_service.dart` | `submitQuestion({required text, int? categoryId, required language, List<String> answerOptions = const []})`; `category_id` is sent only when set, `answer_options` only when non-empty |
| `lib/widgets/create_question_dialog.dart` | category dropdown defaults to "No category" (label "Category (optional)"), answer options optional and removable down to zero; only the text is required |
| `lib/services/admin_service.dart` | `approveQuestion(id, {minAge, specialCategory, categoryId, answerOptions})` |
| `lib/pages/admin_submission_detail_page.dart` | approval settings with a prefilled category dropdown and an answer-options editor; *Approve* disabled until a category is selected and the question has at least two options (the ones the submitter provided plus the ones entered); the editor stays visible while the question is short of two and is replaced by a note once it is complete; backend `error` message shown on failure |
| `lib/pages/my_submissions_page.dart`, `lib/pages/admin_submissions_page.dart` | submissions without a category show the localized "Uncategorized" chip |

Notes for backend implementers:

- The dialog uses a sentinel (`0`) for "no category" and sends no `category_id` at all in
  that case; it never sends `null`.
- The admin page always sends `category_id` when one is selected, and sends
  `answer_options` only while the question has fewer than two; the backend appends them to
  the options the submitter provided.
- The client caps answer options at 50 but otherwise trusts the backend; validation errors
  are displayed verbatim, so precise `error` messages matter.

## Acceptance criteria

Backend:

1. `POST /questions/submissions` with only `text` and `language` returns `201` and creates a
   `pending` question with `category_id: null` and zero answers.
2. `POST /questions/submissions` with `category_id: 999` returns `400`.
3. `POST /questions/submissions` with 51 answer options returns `400`.
4. `POST /admin/questions/{id}/approve` on such a submission without `category_id` and
   without `answer_options` returns `400`.
5. Approving with `category_id` only returns `400` (answers still missing).
6. Approving with `answer_options` only returns `400` (category still missing).
7. Approving with a single answer option returns `400` — an approved question needs two.
8. Approving with both a category and two or more answer options stores the category, inserts
   the answers, sets `approved`, and returns the updated submission with `answer_options`.
9. Approving a submission that arrived with one answer option and a single
   `answer_options` entry succeeds, stores two options (the submitted one first) and keeps the
   submitter's option.
10. Approving a submission that already has two or more answers without `answer_options`
    succeeds and keeps those answers.
11. Approving a submission that already has two or more answers *with* `answer_options`
    returns `409`.
12. An approved question is returned by `restSearch` with its `category_id` and is votable
    through `POST /questions/{id}/answer`.
13. A submission filed with a category and two or more answers behaves exactly as before.

## Risks and open items

- **Old clients are the compatibility anchor.** Any change that renames or drops the
  existing fields breaks them; only relax and add.
- **Message wording.** The client displays the backend `error` string as-is, in English,
  on a localized UI. Keep messages short and actionable, or accept mixed-language errors.
- **Approval is a two-field gate.** If the backend rejects an approval the admin cannot fix
  from the client (e.g. a category deleted between load and approve), the message must say
  what to change.
- **Deleted categories.** If a category is removed while a submission references it, the
  existing `categoryFallback` rendering ("Category {id}") applies.
- **Not covered here.** Bulk approval, editing answers after approval, and a dedicated
  "uncategorized" taxonomy are out of scope.