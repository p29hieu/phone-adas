# Cookbook

Reusable UI / animation building blocks. Rules:

1. **Flutter SDK only** — no third-party imports, ever. A cookbook file must
   compile after being copied alone into any Flutter project.
2. **One concept per file**, self-contained, with a doc comment that includes
   a usage example.
3. **No project imports** — cookbook files never import from `lib/` outside
   this folder (the app depends on the cookbook, never the reverse).
4. Every widget here must have at least one real call site in the app —
   this folder is a toolbox, not a museum.
