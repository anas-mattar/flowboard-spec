# Frontend: Forms Architecture (MANDATORY)

Stack:

| Layer | Library | Purpose |
|-------|---------|---------|
| Validation | Zod (schemas in **lib/\<feature\>/schemas.ts**) | Runtime validation + type inference |
| State | React Hook Form (`useForm`) | Form state, submission, field control |
| UI | shadcn/ui Form (**components/ui/form.tsx**) | `Form`, `FormField`, `FormItem`, `FormLabel`, `FormControl`, `FormMessage` |
| Notifications | Sonner (`toast`) | Success/error notifications |
| API | tRPC mutations | Server communication |

FlowBoard note: the board's inline edits (titles, the card composer) are NOT forms in
this sense — they follow the prototype's interaction contract (Enter commits, Escape
cancels, composer stays open — C-01) as feature-scoped components. This file governs
structured data-entry forms: card detail fields, board settings, invitations, workspace
management.

## Rule F8a — Form component structure (MANDATORY)

Every form in **components/forms/** MUST follow this exact structure:

```tsx
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { trpc } from '@/lib/trpc/client';
import { boardSchema, type Board } from '@/lib/boards/schemas';
import {
  Form, FormControl, FormField, FormItem, FormLabel, FormMessage, FormDescription
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { toast } from 'sonner';

type FormData = z.infer<typeof boardSchema>;

interface BoardFormProps {
  data?: Board;                    // undefined = create
  onCancel?: () => void;
  onSubmitParent?: () => void;     // parent refresh callback
  cancelText?: string;
}

export function BoardForm({
  data, onCancel, onSubmitParent, cancelText = 'Cancel',
}: BoardFormProps) {
  const form = useForm<FormData>({
    resolver: zodResolver(boardSchema),
    defaultValues: {
      name: data?.name ?? '',
      color: data?.color ?? 'blue',
    },
  });

  const addMutation = trpc.boards.add.useMutation();
  const updateMutation = trpc.boards.update.useMutation();

  const onSubmit = async (formData: FormData) => {
    try {
      if (data?.publicId) {
        await updateMutation.mutateAsync({ publicId: data.publicId, ...formData });
        toast.success('Updated successfully');
      } else {
        await addMutation.mutateAsync(formData);
        toast.success('Created successfully');
      }
      onSubmitParent?.();
    } catch {
      toast.error('Something went wrong');
    }
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>
                Name <span className="pl-1 font-bold text-red-500">*</span>
              </FormLabel>
              <FormControl><Input placeholder="Enter board name" {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="flex justify-end space-x-2">
          {onCancel && (
            <Button variant="ghost" type="button" onClick={onCancel}>{cancelText}</Button>
          )}
          <Button disabled={form.formState.isSubmitting} type="submit">
            {data ? 'Update' : 'Add'}
          </Button>
        </div>
      </form>
    </Form>
  );
}
```

## Rule F8a-1 — Mutation wiring (allowed variants)

Two wirings are allowed; field state and validation MUST be RHF + zodResolver in
either case:

1. **Form-owned mutation** (default, as in F8a): the form calls
   `trpc.<router>.<procedure>.useMutation()` directly and notifies the parent via
   `onSubmitParent`.
2. **Page-owned mutation**: the page owning the screen passes an async
   `onSubmit(input)` prop; the page calls the tRPC mutation and owns cache
   invalidation (`trpc.useUtils()`). Use this when one page orchestrates several
   modals/forms over the same query cache (e.g. the card detail modal, which edits
   labels, members, due date, and checklist over one card query).

In both variants the form itself shows Sonner toasts and disables submit via
`form.formState.isSubmitting`.

## Rule F8b — Zod schemas

Live in **lib/\<feature\>/schemas.ts**. Never define Zod schemas inline in form files.

```ts
import { z } from 'zod';

export const cardInputSchema = z.object({
  title: z.string().min(1, 'Title required').max(500),
  description: z.string().optional().nullable(),
  dueAt: z.date().optional().nullable(),
  labelIds: z.array(z.string()).default([]),
});

export const cardUpdateSchema = cardInputSchema.extend({ publicId: z.string() });
export type CardInput = z.infer<typeof cardInputSchema>;
```

## Rule F8c — Field input components

| Field type | Component | Source |
|------------|-----------|--------|
| Text/string | `<Input {...field} />` | `@/components/ui/input` |
| Date | `<DatePicker {...field} />` | custom date picker |
| Domain dropdown | `<MemberDropdown value={field.value} onChange={field.onChange} />` | `@/components/dropdowns/*` |
| Enum select | `<Select>` | `@/components/ui/select` |
| Textarea | `<Textarea {...field} />` | `@/components/ui/textarea` |
| Number | `<Input type="number" {...field} />` | `@/components/ui/input` |

## Rule F8d — File organization

All data-entry forms live in **components/forms/**. Name as `{feature}-form.tsx` or
`{feature}-{action}-form.tsx`.

## Form rules

- Every form MUST use `zodResolver` — no manual validation, no `useState` field state.
- Every form MUST be dual-mode (create/update) via the `data` prop when the entity
  supports both operations. Single-action forms (e.g. invite member) omit the unused
  mode but keep the same structure.
- Required fields MUST show `<span className="pl-1 font-bold text-red-500">*</span>` in `FormLabel`.
- `<FormMessage />` auto-displays Zod errors — no manual wiring.
- Submit button MUST be disabled during submission via `form.formState.isSubmitting`.
- Toast notifications MUST use `sonner` (`toast.success()` / `toast.error()`) — spec
  X-01: every state-changing action gives feedback.
- Cross-field dependencies use `form.watch()` and `form.setValue()`.
- Never use blocking sync calls in form handlers.
