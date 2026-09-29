# <One line: what changed, in the person's words>

## 📍 Where we are

- **Project:** <repo> — <what the app is, in five words>
- **Branch:** `<branch>` · **Plan:** `docs/plans/<plan>.md`
- **Why you're asked:** <one sentence: why a person must look at this before it ships>

## What you should see

<In their words. Say "Nothing new — everything should look exactly like
today" when that is the point of the change.>

## 👉 Try it (about <n> minutes)

1. **Open <http://localhost:PORT/path>** — you land on <what is on screen,
   named the way the person sees it>.
2. **Click "<visible label>"** (<where: top right, next to "…">) — <what
   appears: "a panel titled … slides in from the right">.
3. **Look at <thing>** — <what it should look like; what "broken" would look
   like, e.g. "buttons cramped, text touching their edges">.
4. **<Do the changed interaction>** — <the result they should see>.
5. **<Undo / close>** — <back to the starting state>.

## Reference

![before](before.jpg)
![after](after.jpg)

<One line each: what the before and after screenshots show.>

<!-- When the branch commits a picked mockup (docs/mockups/<screen>/*.dc.html),
`preview register` is in mockup mode and ALSO requires, here: -->
Artboards: docs/mockups/<screen>
Viewport: 1120px · light

![Mockup, direction <X>](artboard.png)
![Built screen](after.png)

<!-- artboard.png / after.png: copies of the proof PNGs committed next to the
artboards, copied beside this guide as their OWN command before the register
(a register chained after `cp` is not bound). after.png is the built route in
a real browser at the artboard's width and theme. -->

## Already checked

- <What the agent verified: browser pass, console errors, tests, and the
  measurement that matters (e.g. padding unchanged)>
- **Look especially at:** <the one thing a person's eye catches better than
  the agent's>

## Differences from the mockup

<!-- Mockup mode only. Compare the artboard and after.png side by side BEFORE
asking; a difference in hierarchy or states is a finding to fix, not a
caption. Then: -->
- fixed: <a difference found and removed>
- deliberate: <a difference kept, and why>
<!-- or the single word: None -->
