import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from 'ee/ai/catalog/constants';
import {
  AGENT_MESSAGES,
  FLOW_MESSAGES,
  THIRD_PARTY_FLOW_MESSAGES,
  MESSAGES_BY_TYPE,
} from 'ee/ai/catalog/messages';

const MESSAGE_GROUPS = ['common', 'disable', 'index', 'show', 'create', 'edit', 'duplicate'];

describe('AGENT_MESSAGES', () => {
  it('contains the documented message groups', () => {
    expect(Object.keys(AGENT_MESSAGES)).toEqual(MESSAGE_GROUPS);
  });
});

describe('FLOW_MESSAGES', () => {
  it('contains the documented message groups', () => {
    expect(Object.keys(FLOW_MESSAGES)).toEqual(MESSAGE_GROUPS);
  });
});

describe('THIRD_PARTY_FLOW_MESSAGES', () => {
  it('contains the documented message groups', () => {
    expect(Object.keys(THIRD_PARTY_FLOW_MESSAGES)).toEqual(MESSAGE_GROUPS);
  });
});

describe('MESSAGES_BY_TYPE', () => {
  it.each([
    [AI_CATALOG_TYPE_AGENT, AGENT_MESSAGES],
    [AI_CATALOG_TYPE_FLOW, FLOW_MESSAGES],
    [AI_CATALOG_TYPE_THIRD_PARTY_FLOW, THIRD_PARTY_FLOW_MESSAGES],
  ])('maps %s to the correct messages object', (type, expected) => {
    expect(MESSAGES_BY_TYPE[type]).toBe(expected);
  });
});
