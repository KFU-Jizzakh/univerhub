# SPEC-CORE-01: Authentication & Session Management

Email/password-based authentication, session persistence, password reset flow, account deactivation, and rate limiting.

Depends on: —

Status: DRAFT

## Acceptance Criteria

- AC-1: User can sign in with email and password
- AC-2: User session persists until sign-out
- AC-3: User can sign out (session destroyed)
- AC-4: Deactivated user is blocked from signing in and receives an alert
- AC-5: Deleted user is blocked from signing in with an account-deleted alert
- AC-6: Failed login returns generic error (no user enumeration)
- AC-7: Login is rate-limited (10 attempts per 3 minutes)
- AC-8: User can request password reset via email
- AC-9: Password reset email is sent in the background
- AC-10: Password reset token is single-use and expires
- AC-11: Invalid or expired reset token is logged and redirects with alert
- AC-12: New password must be at least 8 characters
- AC-13: After password reset, all existing sessions are destroyed
- AC-14: All pages except sign-in and password-reset require authentication
- AC-15: Unauthenticated access stores the intended URL and redirects after login
- AC-16: A deactivated user's active session is terminated on their next request

## UI/UX Notes

- Sign-in form: email + password fields with submit button
- Password reset form: email field, "instructions sent" notice shown regardless of email existence
- Reset password form (from token link): password + confirmation fields
- Deactivated users see "account deactivated" alert on next request
- After login, user is redirected to the stored return URL or a default landing page

## Business Rules

- BR-1: Email is stored in a normalized format (lowercase, whitespace trimmed)
- BR-2: Return URL after login is only followed if it belongs to the application's own domain
- BR-3: Each sign-in is recorded for audit purposes
- BR-4: Session cookie is protected against client-side access and tampering
- BR-5: Deactivated accounts are blocked from authentication
- BR-6: Deleted accounts are blocked from authentication with a different message

## Behavior

### Background
Given a user exists with email `user@example.com` and password `Secret123`

### Rule: Sign In

#### Scenario: Successful sign-in
Given the user is active (not deactivated, not deleted)
When user submits email `User@Example.com` and password `Secret123`
Then a session is created and recorded for audit
And a persistent session cookie is set
And user is redirected to the default page

#### Scenario: Invalid credentials
Given the user is active
When user submits email `user@example.com` and password `WrongPass`
Then user is redirected to sign-in with generic alert
And no session is created

#### Scenario: Deactivated user
Given the user is deactivated
When user submits correct credentials
Then user is redirected to sign-in with "account deactivated" alert
And no session is created

#### Scenario: Deleted user
Given the user is deleted
When user submits correct credentials
Then user is redirected to sign-in with "account deleted" alert
And no session is created

#### Scenario: Rate limit exceeded
Given the user has made 10 failed login attempts within 3 minutes
When user attempts to sign in again
Then user is redirected to sign-in with rate-limit alert

### Rule: Sign Out

#### Scenario: Successful sign-out
Given user is signed in
When user clicks "Sign out"
Then the session is destroyed
And the session cookie is deleted
And user is redirected to sign-in page

### Rule: Password Reset

#### Scenario: Request password reset
When user submits email `user@example.com`
Then a password reset email is sent
And user is redirected to sign-in with success notice

#### Scenario: Request with unknown email
When user submits email `unknown@example.com`
Then no email is sent
And user is redirected to sign-in with same success notice (no enumeration)

#### Scenario: Reset with valid token
Given user has a valid password reset token
When user submits new password and confirmation matching
Then password is updated
And all existing sessions are destroyed
And user is redirected to sign-in with success notice

#### Scenario: Reset with invalid/expired token
Given the token is invalid or expired
When user visits password reset page
Then the attempt is logged with network information
And user is redirected with "link is invalid or expired" alert

### Rule: Authentication Required

#### Scenario: Unauthenticated request to protected page
Given user is not signed in
When user visits any page except sign-in or password-reset
Then user is redirected to sign-in
And the current page URL is stored for post-login redirect

#### Scenario: Return-to after sign-in
Given user was redirected to sign-in from `/admin/users`
When user signs in successfully
Then user is redirected to `/admin/users`

#### Scenario: Deactivated user mid-session
Given user has an active session but account was deactivated
When user makes any authenticated request
Then session is terminated
And user is redirected to sign-in with "deactivated" alert
