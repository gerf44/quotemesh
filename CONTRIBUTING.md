# Contributing

1. Open an issue describing the smallest complete change.
2. Do not change Arc addresses from memory; cite current official documentation.
3. Keep QuoteMesh contracts separate from external Arc/Circle infrastructure.
4. Add or update the smallest test that fails without the change.
5. Run:

```powershell
npm run forge:fmt
npm run forge:test
npm run lint
npm run typecheck
npm run build
```

Never commit secrets, generated deployment claims, sample data presented as live, or modified Arc
brand assets.
