# Test Generation Quality Checklist

Every generated test must satisfy all of the following:

- Assert behavior, not implementation (no testing private methods)
- Use meaningful assertions (no `toBeDefined`, `toBeTruthy` on objects)
- Include at least one error/edge case test per function
- Match the project's existing test conventions exactly
- Not duplicate existing test coverage
- Avoid all anti-patterns from test-review's `references/llm-test-antipatterns.md`:
  no magic numbers, no asserting mock return values, no hallucinated APIs
