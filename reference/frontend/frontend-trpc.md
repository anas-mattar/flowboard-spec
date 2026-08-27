# Frontend tRPC Rules

## FMS BFF Status (codified 2026-06-12, feature 008)

`fms-frontend` currently defines **`publicProcedure` only** (`src/server/api/trpc.ts`).
This is a deliberate Phase-4 decision from feature 004, not an oversight:

- Authorization is enforced by the **backend** on every call. The server-only API
  clients (`src/lib/api/*-client.ts`) attach the caller identity via
  `getApiAuthHeaders()` (Entra bearer token, or `X-FMS-User`/`X-FMS-Roles` in dev),
  and the backend's `perm:*` policies return 401/403.
- The browser never holds the backend token; tRPC procedures run server-side.

**Trigger to change**: when NextAuth session context is added to tRPC, define
`protectedProcedure` and migrate all writes and user-specific reads to it. Until
then, do NOT add ad-hoc auth checks inside procedures — keep enforcement at the
backend boundary.

## Router Organization

Recommended structure:

```text
server/api/
  root.ts
  trpc.ts
  routers/
    purchase-order.ts
    purchase-order/
      list.ts
      cancel.ts
      confirm.ts
```

## Procedure Rules

- Use `publicProcedure` for safe reads if project allows public reads.
- Use `protectedProcedure` for writes or user-specific data **once it exists**
  (see FMS BFF Status above; today all procedures are `publicProcedure` with
  backend-enforced authorization).
- Validate input with Zod (`.input(schema)`) on every procedure that takes input.
- Procedures call the feature's server-only API client in `lib/api/*-client.ts`;
  never `fetch` ad hoc inside a procedure.
- Do not call random external URLs directly from components.

## Router Example

```ts
export const myFeatureRouter = createTRPCRouter({
  list: protectedProcedure
    .input(myFeatureListSchema)
    .query(async ({ ctx, input }) => {
      return ctx.featcher<MyFeatureListResponse>('MyFeature/list', {
        method: 'POST',
        body: JSON.stringify(input),
      });
    }),

  add: protectedProcedure
    .input(myFeatureCreateSchema)
    .mutation(async ({ ctx, input }) => {
      return ctx.featcher<MyFeature>('MyFeature', {
        method: 'POST',
        body: JSON.stringify(input),
      });
    }),

  update: protectedProcedure
    .input(myFeatureUpdateSchema)
    .mutation(async ({ ctx, input }) => {
      return ctx.featcher<MyFeature>(`MyFeature/${input.id}`, {
        method: 'PUT',
        body: JSON.stringify(input),
      });
    }),
});
```

## Error Handling

- Use the project’s existing fetch wrapper behavior.
- Do not expose raw backend stack traces to users.
- Forms should show toast errors.
- Tables should show loading, empty, and error states.
