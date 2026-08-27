# Frontend: Tables Architecture (MANDATORY)

`flowboard-web` uses a **two-layer base table system**. All new tables MUST compose from
these base components — do not duplicate pagination, search, sort, or URL-state logic.

FlowBoard note: the board canvas itself is NOT a table — it is a feature-scoped
component. This file governs tabular list screens: workspace members, board members,
archived items, admin/audit lists.

Composition levels:

- **Server-paged lists** (the normal case) compose `QueryDataTable` (Layer 2):
  URL-driven page/limit/search/sortBy/sortDir.
- **Matrix-style grids** (dynamic columns, full dataset rendered, no server paging —
  e.g. the permissions matrix from spec §6) may compose `BaseDataTable` (Layer 1)
  directly with a `ColumnDef` factory. They still get `columns.tsx` and the feature
  folder; they skip URL state because there is nothing to page.

Matrix-grid support on `BaseDataTable`:

- Per-column styling via tanstack `ColumnDef.meta`: `headerClassName` /
  `cellClassName` are merged onto the `<th>`/`<td>` (e.g. sticky first columns,
  centered checkbox cells).
- Labelled section bands via the optional `rowGroupHeader` prop
  (`{ getGroupKey, render, rowClassName?, cellClassName? }`): a full-width band row is
  rendered whenever `getGroupKey` changes between consecutive rows.

## Layered structure

```text
Layer 0: components/ui/table.tsx          Pure HTML primitives
Layer 1: base/base-data-table.tsx         BaseDataTable<TData, TFilter>
         @tanstack/react-table, rendering, debounced search,
         pagination UI, sorting UI, filter slots, loading/empty
Layer 2: base/query-data-table.tsx        QueryDataTable<TData, TFilter>
         Wraps BaseDataTable + URL state (page/limit/search/sortBy/sortDir
         as query params), tRPC query execution, page-bounds correction
Layer 3: Feature tables                   MembersTable, ArchivedCardsTable, ...
         Concrete tRPC hook wrapper, domain filter state, column defs,
         configuration (enableSorting, searchPlaceholder, etc.)
```

## Base types

```ts
// base/base-data-table.tsx
export interface PaginatedResponse<T> {
  items: T[];
  totalPages: number;
  totalCount?: number;
  currentPage?: number;
}

export interface BaseTableFilter {
  searchTerm?: string;
  boardId?: string;
  workspaceId?: string;
}

export interface BaseTableConfig {
  enableSorting?: boolean;
  enableFiltering?: boolean;
  enablePagination?: boolean;
  searchPlaceholder?: string;
  searchKey?: string;
  pageSizeOptions?: number[];
  defaultPageSize?: number;
  tableHeight?: string;
  searchFromUrl?: boolean;
}

// base/query-data-table.tsx
export interface QueryParams<TFilter extends BaseTableFilter> {
  page: number;
  size: number;
  sortBy?: string;
  sortDir?: 'asc' | 'desc';
  filter: TFilter;
}

export interface QueryResult {
  data: any;
  isLoading: boolean;
  isFetching: boolean;
  refetch: (options?: any) => Promise<any>;
}
```

## Rule F11a — Creating a new table

Compose `QueryDataTable`. Never rewrite table boilerplate.

```tsx
'use client';
import React, { useState, useCallback } from 'react';
import { type ColumnDef } from '@tanstack/react-table';
import { trpc } from '@/lib/trpc/client';
import { QueryDataTable, type BaseTableFilter } from '@/components/tables/base';

interface MembersTableFilter extends BaseTableFilter {
  role?: string;
}

interface MembersTableProps<TData> {
  columns: ColumnDef<TData, unknown>[];
  actions?: React.ReactNode;
}

export function MembersTable<TData>({ columns, actions }: MembersTableProps<TData>) {
  const [role, setRole] = useState<string | undefined>(undefined);

  const useMembersQuery = (params: {
    page: number; size: number; sortBy?: string; sortDir?: 'asc' | 'desc';
    filter: MembersTableFilter;
  }) => {
    const result = trpc.members.list.useQuery({
      page: params.page,
      size: params.size,
      sortBy: params.sortBy,
      sortDir: params.sortDir,
      filter: { ...params.filter, role: role === 'SelectValue:All' ? undefined : role },
    });
    return {
      data: result.data ?? undefined,
      isLoading: result.isLoading,
      isFetching: result.isFetching,
      refetch: result.refetch,
    };
  };

  const handleClearFilters = useCallback(() => setRole(undefined), []);

  const filterComponents = [
    <RoleDropdown key="role" value={role ?? 'SelectValue:All'} onChange={setRole} showSelectAll />,
  ];

  return (
    <QueryDataTable
      columns={columns}
      useQuery={useMembersQuery}
      filterComponents={filterComponents}
      onClearFilters={handleClearFilters}
      actions={actions}
      config={{
        enableSorting: true,
        enableFiltering: true,
        searchPlaceholder: 'Search members...',
        pageSizeOptions: [10, 20, 30, 40, 50],
      }}
      emptyMessage="No results found."
    />
  );
}
```

## Rule F11b — Column definitions

Columns live in a separate `columns.tsx` using `ColumnDef<T>` from
`@tanstack/react-table`.

```tsx
'use client';
import { type ColumnDef } from '@tanstack/react-table';
import { type Member } from '@/lib/members/schemas';
import { CellAction } from './cell-action';
import { formatDate } from '@/lib/utils';

export const columns: ColumnDef<Member>[] = [
  { accessorKey: 'displayName', header: 'Name' },
  { accessorKey: 'email', header: 'Email' },
  {
    accessorKey: 'role',
    header: 'Role',
    cell: (cell) => <RoleBadge role={cell.row.original.role} />,
  },
  {
    accessorKey: 'createdDate',
    header: 'Joined',
    cell: ({ row }) => <div>{row.original.createdDate ? formatDate(row.original.createdDate) : '-'}</div>,
  },
  { id: 'actions', cell: ({ row }) => <CellAction data={row.original} /> }, // ALWAYS last
];
```

Column variants via slicing:

```tsx
export const columnsWithExtra = [
  ...columns.slice(0, 3),
  { accessorKey: 'extraField', header: 'Extra' },
  ...columns.slice(3),
];
```

Column rules:

- Every feature folder MUST have a `columns.tsx`.
- Use `accessorKey` for simple data; `cell` for custom JSX (badges, links, formatted
  values).
- `id: 'actions'` MUST be last. Optional `id: 'select'` checkbox column goes first.
- Export variant columns as separate constants/factories. Never define columns inline.

## Rule F11c — File organization

```text
components/tables/{feature}-tables/
├── table.tsx           # composes QueryDataTable
├── columns.tsx         # ColumnDef<T>[]
└── cell-action.tsx     # row action dropdown (only when rows have actions)
```

Sub-tables:

```text
components/tables/{feature}-tables/
├── table.tsx
├── columns.tsx
├── cell-action.tsx
└── {sub-feature}/
    ├── table.tsx
    ├── columns.tsx
    └── cell-action.tsx
```
