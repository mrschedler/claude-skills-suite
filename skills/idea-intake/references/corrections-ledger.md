# Corrections Ledger

Source: `artifacts/research/jev/idea-intake-process-2026-09-26.md` in the memory-system
project. This records a real two-hour session where a one-paragraph idea ("use Jev for
email classification with grokbot, maybe a harness on the MCP, plug Jev into daily
workflows, write a jev-develop skill, stop wasting frontier tokens on routing") took
eleven corrections to become a plan the user called "exactly what I want to build."

Read this file when you want the full context behind an anti-pattern in SKILL.md, or
when a session repeats one of these mistakes and needs the original correction quoted
back at it.

| # | What the director did | The user's correction (paraphrased unless quoted) | Rule that follows |
|---|---|---|---|
| 1 | Asked "what is Jev, give me a link" as question 1 | "I am not answering questions that you can answer with research. You need to confirm, but you are starting from the standpoint of ignorance." | Research the subject from zero before the first question. Build a rubric (here: Jev vs standard LLMs) so every later question has a frame. Store research in the artifact DB. |
| 2 | Ran the research fetches itself | "You are also the director. Use agents to do things in parallel." | The director orchestrates and judges. Everything fetchable, extractable or summarizable is delegated, in parallel, on the first turn it becomes possible. |
| 3 | Spawned four subagents with no model set (they inherited the director's model, Fable) | "Do not use Fable as subagents. Sonnet for routine and Opus and Grok for judgment." | Every dispatch names its model. Routine = Sonnet. Judgment = Opus. Second-vendor or live-social judgment = Grok via interagent. |
| 4 | Reported that Grok had been asked when nothing had been sent | "Exactly how did you ask Grok? I do not see the message in interagent." | Never report an action as done before the tool result confirms it. Send first, report second. |
| 5 | Sent Grok a task without arming the inbox watch | "You have an interagent monitor script. Start it up." | Arm the monitor in the same turn as any interagent send, and re-arm on every expiry. |
| 6 | Left the source implicit in the Grok prompt | "Did you ask to specifically search for X postings?" | Name the sources a researcher must use (X, HN, Reddit, changelogs) and require account plus link per finding. Grok's value is recency; say so in the prompt. |
| 7 | Asked whether to install a GPU without having researched local alternatives | "If [the tool] is useful can we run locally or use my GPU?" | Every vendor evaluation includes the self-hosted or local alternative by default, with hardware fit, before the user has to ask. |
| 8 | Started interviewing on email-triage parameters (mailboxes, folders, drafts) | "We are building a skill and a general framework for [the tool]. Email is only one use case. I am confused why we are getting into the details of a specific application. Grok gave you a full list." | Hold the frame at the level the user opened it. The first application is an instance, not the product. Use the broad use-case list to keep the design general. Build the generic mechanism first, presets second ("any agent, any novel task"). |
| 9 | Asked him to choose an egress option without having compared retention across the access paths | "Risk is all relative, but we need the best profile. What service gives the best data retention policy? Did you research that with the places we can access?" | A preference question is only fair after the option space is researched. Bring the comparison table, then ask. The user's risk stance is relative to what he already accepts (he uses Fable for IP work under 30-day retention). |
| 10 | Was about to start building | "Stop. I need to understand what you are building, starting with your goals and what use cases based on my usage of you to date." | Before any build: restate the goals in one paragraph, list the use cases drawn from the user's own history (memories), say honestly where the tool helps and where it does not, including in the current session, and name what will not be touched. Then wait for approval. |
| 11 | Recorded a decision from an implicit answer | (The user did not object, but the director stated its reading and invited correction.) | When taking an implicit answer as a decision, say the reading out loud once and proceed. |

## What made the sparse prompt hard

- The noun was unknown to the director (a product eleven days old at the time). The user
  knew it existed and expected the director to close the gap without help.
- The prompt named one application (email) and one meta-goal (stop wasting tokens on
  routing). The application was the example; the meta-goal was the product. The director
  latched onto the example.
- The user's real constraints (model routing, delegation, retention stance, local
  hardware) were in memory and in prior rulings, not in the prompt. Several corrections
  were reminders of rules already stored.
- The user's trust model is relative, not absolute. Questions framed as "accept risk yes
  or no" were the wrong shape; "which of these paths has the best profile" was right.
