# Notice

This skill is copied from `better-accessibility/` in
https://github.com/jakubkrehel/skills, at commit
`4c66b1fa86e9ab70187b43d7da9b6fdb29f2ef63` (fetched 2026-10-16).

Local edits: the `better-` prefix is dropped from the skill name, the `name:` line and the cross-references (done by `scripts/fork-interface-skills.sh`), and `agents/openai.yaml` is not copied. A precedence block is added after the intro: a decision of this repository outranks a value in this skill. The hand-offs to `colors` (contrast) and `typography` (iOS `16px` input) are reconciled: where those skills are absent it computes the declared pair's ratio against its own 1.4.3/1.4.11 table and marks rendered-background pairs `Not verified`, and where `typography` is absent it sets input font size to at least `16px` itself.

Updating: diff the upstream path from the pinned commit above, have a frontier
model port the changes over the local edits, then bump the pinned commit.

The original is distributed under the MIT License:

> MIT License
>
> Copyright (c) 2026 Jakub Krehel
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.
