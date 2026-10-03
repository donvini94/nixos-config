---
name: calendar-to-org-agenda
description: "Turn a pasted calendar screenshot into deduplicated, correctly dated entries in gtd/agenda.org, preserving Org structure and recurring timestamps."
---

# Calendar screenshot to Org agenda

Use this skill when Vincenzo pastes a calendar screenshot and asks to add or reconcile its events in `gtd/agenda.org`.

## Invariants

- `gtd/agenda.org` is the source of truth. Read its current contents before every import; it may have been manually corrected since the last run.
- Preserve existing Org structure, event titles, tags, and manual edits. Do not replace or reorder unrelated entries.
- Do not create duplicate agenda events. Calendar views can show duplicate/forwarded invitations side by side.
- Work documents in this repository are Org-mode; write Org entries, never Markdown.
- Never guess an event date or time that is not visible or reliably inferable from the screenshot.

## Read the screenshot

1. Identify the calendar date range from the visible day/date headers. Use the year shown by the calendar; if it is omitted, infer it only when the displayed dates plus current context establish one unambiguously.
2. Read the timezone label and the time axis. Use the screenshot's local calendar times. Map event block top/bottom to start/end using the visible time grid; all-day cards have a date but no time range.
3. Transcribe each event title, date, and time range. Preserve useful names. Strip leading `FW:` prefixes (including repeated prefixes) because they are forwarding artifacts, not part of the meeting name.
4. Treat exact or normalized-title duplicates at the same date/time as one event. Normalize titles by removing leading `FW:` prefixes, trimming whitespace, and comparing case-insensitively. When duplicate cards have small title differences caused only by forwarding prefixes, keep one clean title and one timestamp. Do not collapse genuinely distinct events merely because they overlap.
5. If the date header, timezone or time axis is cropped, or a relevant title/time is illegible, complete the unambiguous entries and ask only for the missing information needed to place the rest. Do not invent times from card height without a visible scale.

## Decide recurrence

Use visible recurrence indicators when they can be read confidently, explicit user instructions, clear recurrence language in the title (for example `Daily`, `Weekly`, or `1:1` when the surrounding calendar supports a repeating series), and repeated weekday/time appearances as evidence. A single screenshot week does not by itself prove that every event recurs.

- Use a one-off timestamp without a repeater for events shown as one-off or not supported as recurring.
- A handover is one-off by default unless the screenshot or user explicitly shows that it repeats.
- Respect explicit cadence: weekly uses `+1w`; every two weeks uses `+2w`.
- For a meeting repeated on multiple weekdays, create one heading and place one recurring timestamp line for each weekday occurrence under it. This is preferred for dailies and JF sessions. Example:
  ```org
  *** Example Daily :team:
  <2026-09-28 Mon 09:00-09:30 +1w>
  <2026-09-30 Wed 09:00-09:30 +1w>
  ```
- Keep different series with distinct names separate, even if both are called a daily. Do not generate a daily series on unshown weekdays without evidence.
- When recurrence is genuinely unclear and it changes future agenda behavior, do not silently choose a repeating event; add it as a one-off only if that matches the user's stated request, otherwise ask a focused clarification.

## Update `gtd/agenda.org`

1. Match each screenshot event against current entries by normalized title and matching date/time. If it already exists, do not add it again. If the screenshot clarifies recurrence for an existing entry, update that entry rather than duplicating it.
2. Put personal appointments under `* Appointments`. Put work meetings under `* Meetings`, separated into the existing `** One-off meetings` and `** Recurring meetings` headings. Preserve the file's existing heading/tag conventions; retain a known tag when the event clearly matches an existing category, and do not invent tags.
3. Use the event's cleanest title. Remove leading `FW:` prefixes. If one recurring series has multiple dates, use one heading with multiple timestamps rather than repeated headings.
4. Use standard Org active timestamps, with ranges for timed events and no time range for all-day events. Add the repeater inside the timestamp:
   - `<2026-10-02 Fri 10:30-11:00>` — one-off
   - `<2026-10-02 Fri 10:30-11:00 +1w>` — weekly
   - `<2026-10-02 Fri 10:30-11:00 +2w>` — every two weeks
5. Make surgical edits. Preserve existing notes, IDs, tags and entries not implicated by the screenshot. If a one-off has already happened in the screenshot's week, still record its shown date; do not roll it forward.

## Verify and report

- Re-read the changed portion of `gtd/agenda.org` after editing.
- Check that no leading `FW:` remains in imported titles, duplicate cards did not become duplicate entries, multi-day series use one heading with multiple timestamp lines, and each repeater matches the evidence or explicit instruction.
- Report the date range added, what was classified as recurring versus one-off, any duplicates consolidated, and any unresolved ambiguities. Keep this brief. Do not claim an uncertain time or recurrence as fact.
