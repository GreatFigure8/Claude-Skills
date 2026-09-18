Builder for the health-check report.
- data.py: all findings, domains, tables and chart series. Replace every value with what you measured; keep the structure.
- build.py: assembles the self-contained HTML (design-system CSS, embedded fonts and logo, page CSS, interaction JS). Output path via HC_OUT env var (default /mnt/user-data/outputs/HCM_Health_Check.html).
- tpl/: design-system CSS (fonts stripped), font subsets (.bin = woff2), cleaned Hackett logo.
The data.py shipped here is the IP PROD run of 12 Sep 2026 and doubles as a worked example of tone, granularity and phrasing.
