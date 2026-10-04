// Runtime fake of the run's session-helper contract (src/lib/dal.ts).
import { redirect } from 'next/navigation.js'

export type Session = { userId: string; role: 'admin' | 'user' }
export const sessionBox: { current: Session | null } = { current: { userId: 'u1', role: 'user' } }

export async function getSession(): Promise<Session | null> {
  return sessionBox.current
}

export async function verifySession(): Promise<Session> {
  const session = await getSession()
  if (!session) redirect('/login')
  return session
}
