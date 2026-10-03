---
name: meeting-minutes
description: "Turn meeting transcripts or notes, especially noisy MacWhisper exports, into factual Org-mode minutes with decisions, owned actions, and explicit attribution uncertainty."
---

# Purpose

Create concise, actionable meeting minutes from transcripts, recordings, or rough notes. The primary record is what changed: decisions, commitments, unresolved questions, and the next move.

Use this skill for internal meetings, customer calls, one-to-ones, design reviews, planning sessions, and ad-hoc discussions. It is not limited to 60-minute meetings.

# Invariants

- Output is Org mode, never Markdown.
- Never invent a speaker, attendee, decision, action owner, deadline, rationale, or consensus.
- A proposal is not a decision. A discussion point is not an action item. “We should” is not an assigned commitment.
- MacWhisper speaker labels are untrusted until supported by the transcript or user-provided mapping.
- Preserve the meeting’s language unless the user asks for translation.
- Put outcomes, decisions, and actions before chronological notes.
- Use canonical tags from `roam/main/tags.org`; `:meeting:` is required and the complete filetag set stays within the repository limit.

# Workflow

## 1. Inspect the source

Use available metadata and files before asking questions. Establish:

- title or subject
- date and approximate duration, if present
- source type: transcript, recording, notes, or combination
- known organizer and participants
- whether an agenda exists
- whether timestamps exist

Ask only when a missing fact materially changes the record or destination. Do not block drafting for absent administrative metadata; write `Unknown` or `Not recorded` instead.

## 2. Assess transcript reliability

Treat speech recognition and speaker diarization as separate problems.

For transcription errors:

- Correct an obvious word only when context makes the correction unambiguous.
- Preserve domain names, product names, figures, dates, and negations exactly when possible.
- Mark consequential uncertainty as `[unclear HH:MM:SS]` or `[wording uncertain]`; do not silently repair it.

For MacWhisper or other automatic speaker labels:

1. Start with every `Speaker N` label as unverified.
2. Look for strong identity anchors: explicit self-identification, another participant addressing the speaker by name, or a user-provided mapping.
3. Do not identify speakers from role, topic expertise, writing style, or a single first-person statement alone.
4. Check a proposed mapping across the full transcript. Contradictions or implausible switches invalidate it.
5. If mapping is stable and supported, use the person’s name. If not, omit personal attribution from discussion notes.

Attribution policy:

- `Confirmed`: supported by explicit evidence or a user-provided mapping; name the person.
- `Uncertain`: materially relevant but not established; write `Speaker unclear` and retain a timestamp.
- `Irrelevant`: attribution does not affect the record; summarize neutrally without a speaker.

Never turn weak diarization into false certainty. Do not equate a MacWhisper speaker number with a person across different recordings.

## 3. Extract claims by status

Make one evidence pass over the source and classify each candidate:

- `Decision`: explicitly agreed, approved, selected, rejected, or locked.
- `Action`: a concrete future task with an explicit commitment or assignment.
- `Open question`: unresolved and expected to be answered.
- `Parking lot`: deliberately deferred or out of scope.
- `Risk/blocker`: threatens progress or prevents a next step.
- `Discussion`: context or reasoning that explains the above.

For every decision and action, retain a timestamp when available. If the transcript reverses an earlier position, record only the final state and briefly note the superseded position when needed to prevent misunderstanding.

Action-field rules:

- Owner: name only when explicitly assigned or clearly self-committed; otherwise `Unassigned`.
- Due: use the stated date or timeframe; otherwise `Not set`.
- Done when: include an expressed outcome or an unambiguous observable completion condition. Otherwise `Not specified`.
- Do not infer ownership from who suggested the task, spoke most about it, or usually owns that domain.

## 4. Draft the Org note

Use this structure. Omit empty optional sections rather than filling the note with `None` or `TBD`.

```org
:PROPERTIES:
:ID:       <uuid>
:END:
#+title: <meeting title>
#+date: <YYYY-MM-DD Day>
#+filetags: :meeting:<up to three canonical tags>:

* Outcome
<One to three sentences: why the meeting happened and what changed.>

* Decisions
- *D1 — <decision>*
  - Rationale: <brief reason, only if supported>
  - Decided by: <name/group, Speaker unclear, or Not recorded>
  - Source: <timestamp, if available>

* Action Items
| ID | Action | Owner | Due | Done when | Source |
|----+--------+-------+-----+-----------+--------|
| A1 | ...    | ...   | ... | ...       | ...    |

* Meeting Details
- Date: <date>
- Time / duration: <value or Not recorded>
- Organizer: <value or Not recorded>
- Present: <confirmed names; otherwise Not fully established>
- Source: <transcript/recording/notes and link or path when useful>

* Agenda
- ...

* Discussion by Agenda Item
** <agenda item>
- <facts and relevant rationale>

* Open Questions
- *Q1 — <question>*
  - Owner: <name or Unassigned>
  - Resolve by: <date/timeframe or Not set>

* Parking Lot
- ...

* Risks / Blockers
- ...

* Follow-up
- Next meeting: <date or Not scheduled>
- Intended objective: <if stated>

* Attribution Notes
- <Only ambiguities that affect a decision, action, quotation, or attendee record.>
```

When there are no decisions or actions, keep the respective heading and write `- None recorded.` This distinction is important; do not omit the two primary sections.

## 5. File placement

When writing into the Org knowledge base:

- Create the note in `roam/meetings/` unless the user gives another destination.
- Follow the existing timestamped, snake_case filename convention.
- Generate a real UUID for the Org-roam `:ID:`.
- Link people and product/topic nodes when their existing Org-roam targets are known; do not invent links or use names as tags.
- Reference the original transcript by path or URL when retained. Do not duplicate the raw transcript into the minutes unless requested.

## 6. Quality gate

Before delivery, check:

- The Outcome states the meeting’s consequence, not a generic topic summary.
- Every decision was actually decided.
- Every action was actually committed or assigned.
- Unknown owner and due date fields remain explicit rather than guessed.
- Speaker names are used only at the supported confidence level.
- The final position wins over superseded discussion.
- Important figures, dates, constraints, objections, and negations survived summarization.
- Sensitive personal material not needed for the business record is excluded.
- The file is valid Org and uses no non-canonical or excess tags.

# Concise mode

For a short or low-substance meeting, use only:

```org
* Outcome
* Decisions
* Action Items
* Open Questions
* Follow-up
```

Keep `Decisions` and `Action Items` even when each contains `- None recorded.`
