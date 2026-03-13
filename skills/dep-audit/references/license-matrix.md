# License Compatibility Matrix

Reference for dep-audit §6. Covers the most common open-source licenses and their
interactions with different project license types.

## Quick Reference

| Dependency License | Proprietary/Commercial | MIT/BSD Project | Apache-2.0 Project | GPL-2.0 Project | GPL-3.0 Project | AGPL-3.0 Project |
|---|---|---|---|---|---|---|
| **MIT** | OK | OK | OK | OK | OK | OK |
| **BSD-2/3** | OK | OK | OK | OK | OK | OK |
| **ISC** | OK | OK | OK | OK | OK | OK |
| **Apache-2.0** | OK | OK | OK | CAUTION* | OK | OK |
| **MPL-2.0** | OK (file-level) | OK | OK | OK | OK | OK |
| **LGPL-2.1** | OK (dynamic link) | OK | OK | OK | OK | OK |
| **LGPL-3.0** | OK (dynamic link) | OK | OK | CONFLICT | OK | OK |
| **GPL-2.0** | CONFLICT | CONFLICT | CONFLICT | OK | CONFLICT** | CONFLICT |
| **GPL-3.0** | CONFLICT | CONFLICT | CONFLICT | CONFLICT** | OK | OK |
| **AGPL-3.0** | CONFLICT | CONFLICT | CONFLICT | CONFLICT | CONFLICT*** | OK |
| **BSL-1.1** | CHECK TERMS | CHECK TERMS | CHECK TERMS | CONFLICT | CONFLICT | CONFLICT |
| **SSPL** | CONFLICT | CONFLICT | CONFLICT | CONFLICT | CONFLICT | CONFLICT |
| **Unlicense** | OK | OK | OK | OK | OK | OK |
| **CC0** | OK | OK | OK | OK | OK | OK |
| **No License** | CONFLICT | CONFLICT | CONFLICT | CONFLICT | CONFLICT | CONFLICT |

\* Apache-2.0 has a patent retaliation clause that may conflict with GPL-2.0 (FSF considers them incompatible).
\** GPL-2.0-only and GPL-3.0-only are incompatible. "GPL-2.0-or-later" is compatible with GPL-3.0.
\*** AGPL-3.0 adds network-use trigger. GPL-3.0 projects can use AGPL-3.0 deps but become effectively AGPL.

## License Categories

### Permissive Licenses (OK for almost all projects)

- **MIT**: No restrictions beyond attribution. Most common in npm ecosystem.
- **BSD-2-Clause / BSD-3-Clause**: Similar to MIT. BSD-3 adds non-endorsement clause.
- **ISC**: Functionally identical to MIT. Common in Node.js core packages.
- **Unlicense / CC0**: Public domain dedication. No restrictions at all.
- **Apache-2.0**: Permissive with patent grant. Explicit patent protection for users.
  Incompatible with GPL-2.0-only (FSF opinion).

### Weak Copyleft (require source for modified files only)

- **MPL-2.0 (Mozilla Public License)**: Copyleft applies per-file. You can combine
  MPL files with proprietary code as long as MPL files remain open. Modifications to
  MPL files must be shared.
- **LGPL-2.1 / LGPL-3.0 (Lesser GPL)**: Designed for libraries. You can link
  dynamically without copyleft trigger. Static linking or modification of the library
  itself triggers copyleft. LGPL-3.0 adds anti-tivoization clause.

### Strong Copyleft (viral — derivative works must use same license)

- **GPL-2.0**: Any code that links/includes GPL-2.0 code must also be GPL-2.0.
  "GPL-2.0-only" vs "GPL-2.0-or-later" matters for compatibility with GPL-3.0.
- **GPL-3.0**: Same as GPL-2.0 plus patent provisions and anti-tivoization.
  Incompatible with GPL-2.0-only.
- **AGPL-3.0**: Same as GPL-3.0 plus network-use trigger. Providing access to the
  software over a network (SaaS) triggers the source distribution requirement.
  This is the most restrictive common open-source license.

### Source-Available / Restrictive

- **BSL-1.1 (Business Source License)**: Not open source. Source is available but
  commercial use is restricted until the change date. Terms vary per project.
  Examples: HashiCorp (Terraform, Vault), MariaDB.
- **SSPL (Server Side Public License)**: MongoDB's license. Requires that anyone
  offering the software as a service must open-source their entire service stack.
  OSI does not consider this open source.
- **Elastic License 2.0**: Permits most use but prohibits offering as a managed service.
  Not OSI-approved.

### No License

If a package has no license file, no license field in its manifest, and no SPDX
identifier — it is **All Rights Reserved** by default. You legally cannot use it.
This is a CRITICAL finding. Contact the maintainer to add a license, or replace
the dependency.

## Common Conflict Scenarios

### Scenario 1: GPL dependency in MIT project
**Problem**: Your MIT project includes a GPL-3.0 dependency. The GPL requires that
your entire project become GPL-3.0.
**Severity**: CRITICAL
**Resolution**: Replace the dependency with a permissive alternative, or relicense
your project under GPL-3.0.

### Scenario 2: AGPL dependency in SaaS product
**Problem**: Your proprietary SaaS uses an AGPL-3.0 library. Users access your
software over the network, triggering the AGPL's network-use clause. You must
distribute source for your entire application.
**Severity**: CRITICAL
**Resolution**: Replace the dependency, purchase a commercial license (if available),
or open-source your application under AGPL-3.0.

### Scenario 3: License changed between versions
**Problem**: A package was MIT in v2.x but changed to BSL-1.1 in v3.x (e.g.,
HashiCorp tools, Elasticsearch). Your lock file pins v3.x.
**Severity**: HIGH (depending on BSL terms)
**Resolution**: Check if v2.x (MIT) still receives security patches. If not,
evaluate BSL terms or find an alternative (e.g., OpenTofu for Terraform,
OpenSearch for Elasticsearch).

### Scenario 4: Transitive GPL contamination
**Problem**: Your direct dependency is MIT, but it depends on a GPL package.
The GPL's copyleft may propagate through the dependency chain.
**Severity**: HIGH
**Resolution**: Check if the transitive dependency is dynamically linked (may
be OK under LGPL) or if it's actually used at runtime. Some build-time-only
dependencies don't trigger copyleft.

### Scenario 5: Dual-licensed package
**Problem**: A package offers "MIT OR GPL-3.0". Which applies?
**Severity**: LOW (usually)
**Resolution**: You can choose either license. Pick the one compatible with your
project. The `OR` in SPDX means you have a choice.

## Detection Checklist

When analyzing license output, flag:

1. **CRITICAL**: Any GPL/AGPL dependency in a proprietary/commercial project
2. **CRITICAL**: Any package with no license
3. **HIGH**: SSPL/BSL dependencies (check specific terms)
4. **HIGH**: License changed between pinned version and latest version
5. **MEDIUM**: LGPL dependencies that are statically linked
6. **MEDIUM**: Apache-2.0 dependency in a GPL-2.0-only project
7. **LOW**: Dual-licensed packages where the chosen license isn't documented
8. **LOW**: Custom/non-SPDX licenses (require manual review)
