import { s__ } from '~/locale';

// Predefined Rego starting points offered from the "Browse templates" modal on
// custom Rego fields. `rego` is inserted verbatim into the editor when picked.
/* eslint-disable @gitlab/require-i18n-strings -- Rego snippets are code, not translatable copy */
export const DEPLOYMENT_GATE_REGO = `package governance
import rego.v1

matches contains msg if {
  input.environment.name == "production"
  msg := "Production deployment blocked"
}`;

export const REGO_TEMPLATES = [
  {
    id: 'blank',
    name: s__('PolicyStore|Blank Template'),
    description: s__('PolicyStore|Start from scratch'),
    icon: 'doc-text',
    rego: 'default allow := false\n',
  },
  {
    id: 'deployment_gate',
    name: s__('PolicyStore|Deployment Gate'),
    description: s__('PolicyStore|Validate deployment prerequisites'),
    icon: 'doc-text',
    rego: DEPLOYMENT_GATE_REGO,
  },
  {
    id: 'agent_tool_access_control',
    name: s__('PolicyStore|Agent Tool Access Control'),
    description: s__('PolicyStore|Restrict which tools an AI agent may call'),
    icon: 'tanuki-ai',
    rego: 'allowed_tools := {"read_file", "search", "list_directory"}\n\ndefault allow := false\n\nallow if {\n    every tool in input.agent.requested_tools {\n        tool in allowed_tools\n    }\n}',
  },
];
/* eslint-enable @gitlab/require-i18n-strings */
