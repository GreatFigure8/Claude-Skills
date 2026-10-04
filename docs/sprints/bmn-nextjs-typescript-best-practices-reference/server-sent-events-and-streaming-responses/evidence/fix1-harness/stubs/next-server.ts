// Records after() tasks instead of needing a Next request scope.
export const afterTasks: unknown[] = []
export function after(task: unknown): void {
  afterTasks.push(task)
}
