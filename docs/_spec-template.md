# SPEC-NN: Feature name

<One paragraph: what the feature does, who is involved, what the outcome is.>

Depends on: SPEC-X, SPEC-Y | —

Status: [PLANNED] | [IMPLEMENTED]

<!-- ## Data Model (field table, if needed) -->

## Acceptance Criteria

- AC-1: ...
- AC-2: ...

## UI/UX Notes

- ...
- ...

## Business Rules

- BR-1: ...
- BR-2: ...

## Behavior

<!-- Background sets context for ALL scenarios below -->

### Background
Given <general initial state>
And   <additional setup>

<!-- Rule groups scenarios tied to one business rule -->

### Rule: <Rule name — references a BR>

#### Scenario: Happy path

Given <specific initial state>
When  <action>
Then  <expected result>

#### Scenario: Negative path

Given <specific initial state>
When  <incorrect action>
Then  <error or refusal>
But   <the system does NOT do X>

<!-- Scenario Outline for parameterised scenarios -->

### Rule: <Another rule>

#### Scenario Outline: <Parameterised scenario>

Given <state with parameter `<param>`>
When  <action with `<param>`>
Then  <result determined by `<param>`>

##### Examples:

| param | expected |
|-------|----------|
| ...   | ...      |
| ...   | ...      |

