import { formatEventName, getClientType } from 'ee/agent_artifacts/utils';
import { DEFAULT_CLIENT_TYPE, CLIENT_TYPES } from 'ee/agent_artifacts/constants';

describe('getClientType', () => {
  it('returns the default client type when item has no clientType', () => {
    expect(getClientType({})).toBe(DEFAULT_CLIENT_TYPE);
  });

  it('returns the default client type when item.clientType is not a known key', () => {
    expect(getClientType({ clientType: 'UNKNOWN_TYPE' })).toBe(DEFAULT_CLIENT_TYPE);
  });

  it('returns the matching client type when item.clientType is a known key', () => {
    expect(getClientType({ clientType: 'GITLAB_DUO' })).toBe(CLIENT_TYPES.GITLAB_DUO);
  });
});

describe('formatEventName', () => {
  describe('with ai_ prefix', () => {
    it.each([
      ['ai_agent_session_ended', 'Agent session ended'],
      ['ai_llm_input_sent', 'Llm input sent'],
      ['ai_tool_invoked', 'Tool invoked'],
    ])('converts %s to %s', (input, expected) => {
      expect(formatEventName(input)).toBe(expected);
    });
  });

  describe('without ai_ prefix', () => {
    it('capitalises the first letter and replaces underscores with spaces', () => {
      expect(formatEventName('tool_execution')).toBe('Tool execution');
    });
  });

  describe('falsy input guard', () => {
    it.each([null, undefined, ''])('returns an empty string for %s', (input) => {
      expect(formatEventName(input)).toBe('');
    });
  });
});
