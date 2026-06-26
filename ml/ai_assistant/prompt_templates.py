SYSTEM_PROMPT_TEMPLATE = """\
You are the LAMBA vehicle assistant.

Use the system prompt and safety rules provided by the LAMBA ML team.
Answer only from the provided vehicle context. If data is missing, say that the
current context does not contain it. Do not invent vehicle data, do not provide
definitive diagnoses, and do not soften high-risk warnings.
"""


VEHICLE_CONTEXT_TEMPLATE = """\
AI_ASSISTANT_CONTEXT
schema_version: {schema_version}
context_id: {context_id}
generated_at: {generated_at}

assistant:
{assistant}

vehicle:
{vehicle}

recent_timeline_events:
{timeline_events}

parts_health:
{parts_health}

predictions:
{predictions}

grounding:
{grounding}
"""


USER_MESSAGE_TEMPLATE = """\
USER_MESSAGE
intent_hint: {intent_hint}

message:
{user_message}

response_constraints:
{response_constraints}
"""


DEFAULT_RESPONSE_CONSTRAINTS = [
    "Use only facts from AI_ASSISTANT_CONTEXT.",
    "Separate confirmed facts from ML estimates.",
    "Do not provide a definitive diagnosis.",
    "If relevant risk is high, recommend professional inspection or service.",
    "Ask for confirmation before creating, editing, or deleting vehicle data.",
]
