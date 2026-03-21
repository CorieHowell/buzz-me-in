import { json } from '@sveltejs/kit'
import { supabase } from '$lib/supabase'

export async function POST({ request }) {
	const { email } = await request.json()

	if (!email || !email.includes('@')) {
		return json({ error: 'Invalid email' }, { status: 400 })
	}

	const { error } = await supabase
		.from('waitlist')
		.insert({ email: email.toLowerCase().trim() })

	if (error) {
		if (error.code === '23505') {
			return json({ success: true }) // already on list, treat as success
		}
		return json({ error: error.message }, { status: 500 })
	}

	return json({ success: true })
}
