# SPEC-CORE-01: Authentication & Session Management

Email/password-based authentication with cookie sessions, password reset flow, account deactivation, and rate limiting.

Depends on: —

Status: DRAFT

## Acceptance Criteria

- AC-1: User can sign in with email and password
- AC-2: User session persists via signed permanent cookie (`session_id`)
- AC-3: User can sign out (session destroyed, cookie deleted)
- AC-4: Deactivated user is blocked from signing in and redirected with alert
- AC-5: Discarded user is redirected on sign-in with account-deleted alert
- AC-6: Failed login returns generic error message (no user enumeration)
- AC-7: Login endpoint is rate-limited (10 requests per 3 minutes)
- AC-8: User can request password reset via email
- AC-9: Password reset sends email asynchronously (deliver_later)
- AC-10: Password reset token is single-use and expires
- AC-11: Password reset invalid signature is logged and redirects with alert
- AC-12: New password must be at least 8 characters
- AC-13: After password reset, all existing sessions are destroyed
- AC-14: All pages except sign-in/password-reset require authentication
- AC-15: Unauthenticated access stores `return_to` URL and redirects after login
- AC-16: Deactivated user's active session is terminated on next authenticated request

## UI/UX Notes

- Sign-in form: email + password fields with submit button
- Password reset form: email field, "instructions sent" notice shown regardless of email existence
- Reset password form (from token link): password + confirmation fields
- Deactivated users see alert: "account deactivated" on next request
- Authenticated pages redirect to `root_url` if `return_to` is invalid or missing

## Business Rules

- BR-1: `User.email_address` is stored normalized (stripped, downcased)
- BR-2: Token URL validation — only redirect to URLs matching current request host
- BR-3: `Session` records user_agent and ip_address for audit
- BR-4: Cookie is httponly, same_site: lax, signed
- BR-5: `User.deactivated_at` presence blocks authentication
- BR-6: `User.discarded_at` presence blocks authentication with different message

## Behavior

### Background
Given a user exists with email `user@example.com` and password `Secret123`

### Rule: Sign In (BR-1, BR-2)

#### Scenario: Successful sign-in
Given the user is active (not deactivated, not discarded)
When user submits email `User@Example.com` and password `Secret123`
Then a new Session is created with user_agent and ip_address
And a signed permanent cookie `session_id` is set
And user is redirected to `root_url`

#### Scenario: Invalid credentials
Given the user is active
When user submits email `user@example.com` and password `WrongPass`
Then user is redirected to sign-in with generic alert
And no session cookie is set

#### Scenario: Deactivated user
Given the user is deactivated (`deactivated_at` is set)
When user submits correct credentials
Then user is redirected to sign-in with "account deactivated" alert
And no session cookie is set

#### Scenario: Discarded user
Given the user is discarded (`discarded_at` is set)
When user submits correct credentials
Then user is redirected to sign-in with "account deleted" alert
And no session cookie is set

#### Scenario: Rate limit exceeded
Given the user has made 10 failed login attempts within 3 minutes
When user attempts to sign in again
Then user is redirected to sign-in with rate-limit alert

### Rule: Sign Out (BR-3)

#### Scenario: Successful sign-out
Given user is signed in with a session
When user clicks "Sign out"
Then the session is destroyed
And the `session_id` cookie is deleted
And user is redirected to sign-in page (303 See Other)

### Rule: Password Reset (BR-4)

#### Scenario: Request password reset
When user submits email `user@example.com`
Then a password reset email is enqueued asynchronously
And user is redirected to sign-in with success notice

#### Scenario: Request with unknown email
When user submits email `unknown@example.com`
Then no email is sent
And user is still redirected to sign-in with same success notice (no enumeration)

#### Scenario: Reset with valid token
Given user has a valid password reset token
When user submits new password and confirmation matching
Then password is updated
And all existing sessions are destroyed
And user is redirected to sign-in with success notice

#### Scenario: Reset with invalid/expired token
Given the token is invalid or expired
When user visits password reset page
Then request is logged with remote IP
And user is redirected with "link is invalid or expired" alert

### Rule: Authentication Required (BR-5, BR-6)

#### Scenario: Unauthenticated request to protected page
Given user is not signed in
When user visits any page except sign-in/password-reset
Then user is redirected to sign-in
And current URL is stored in `return_to_after_authenticating`

#### Scenario: Return-to after sign-in
Given user was redirected to sign-in from `/admin/users`
When user signs in successfully
Then user is redirected to `/admin/users`

#### Scenario: Deactivated user mid-session
Given user has an active session but account was deactivated
When user makes any authenticated request
Then session is terminated
And user is redirected to sign-in with "deactivated" alert
