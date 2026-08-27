# Frontend tRPC Rules

## FlowBoard BFF Status

`flowboard-web` uses tRPC as a BFF between the browser and the .NET API:

- Authorization is enforced by the **backend** on every call (domain invariant 5). The
  server-only API clients (**lib/api/*-client.ts**) attach the caller identity, and the
  backend's permission policies return 401/403.
- The browser never holds the backend token; tRPC procedures run server-side.
- Until feature 002 lands session context, the scaffold defines `publicProcedure` only.
  **Trigger to change**: when the session provider (002) adds auth context to tRPC,
  define `protectedProcedure` and migrate all writes and user-specific reads to it.
  Until then, do NOT add ad-hoc auth checks inside procedures — keep enforcement at the
  backend boundary.

## Router Organization

Recommended structure:

```text
server/api/
  root.ts
  trpc.ts
  routers/
    boards.ts
    cards/
      list.ts
      move.ts
      update.ts
```

## Procedure Rules

- Use `publicProcedure` only for safe reads while `protectedProcedure` does not yet
  exist (see BFF Status above).
- Use `protectedProcedure` for writes or user-specific data **once it exists**.
- Validate input with Zod (`.input(schema)`) on every procedure that takes input.
- Procedures call the feature's server-only API client in **lib/api/*-client.ts**;
  never `fetch` ad hoc inside a procedure.
- Do not call random external URLs directly from components.

## Router Example

```ts
export const cardsRouter = createTRPCRouter({
  list: protectedProcedure
    .input(cardListSchema)
    .query(async ({ ctx, input }) => {
      return ctx.fetcher<CardListResponse>(`lists/${input.listPublicId}/cards`, {
        method: 'GET',
      });
    }),

  add: protectedProcedure
    .input(cardCreateSchema)
    .mutation(async ({ ctx, input }) => {
      return ctx.fetcher<Card>(`lists/${input.listPublicId}/cards`, {
        method: 'POST',
        body: JSON.stringify(input),
      });
    }),

  update: protectedProcedure
    .input(cardUpdateSchema)
    .mutation(async ({ ctx, input }) => {
      return ctx.fetcher<Card>(`cards/${input.publicId}`, {
        method: 'PATCH',
        body: JSON.stringify(input),
        headers: { 'If-Match': input.etag },   // spec §7.1 concurrency
      });
    }),
});
```

## Error Handling

- Use the project's existing fetch wrapper behavior.
- Surface a 409 (stale `If-Match`) as "modified by someone else — refreshed" and
  refetch the card (spec §7.1); never silently overwrite.
- Do not expose raw backend stack traces to users.
- Forms show toast errors.
- Tables show loading, empty, and error states.
