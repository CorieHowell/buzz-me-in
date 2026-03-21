import { redirect } from '@sveltejs/kit'

const ALLOWED = ['/', '/api/waitlist']

export async function handle({ event, resolve }) {
	const path = event.url.pathname
	if (!ALLOWED.includes(path)) {
		redirect(302, '/')
	}
	return resolve(event)
}
