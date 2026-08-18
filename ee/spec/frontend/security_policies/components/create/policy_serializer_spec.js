import { safeLoad } from 'js-yaml';
import {
  buildPolicyObject,
  buildPolicyYaml,
} from 'ee/security_policies/components/create/policy_serializer';

describe('policy_serializer', () => {
  const baseState = () => ({
    policyName: 'My Policy',
    policyDescription: '',
    scope: 'all',
    triggers: [],
    rules: [],
    actions: [],
    triggerConfigs: {},
    ruleConfigs: {},
    actionConfigs: {},
  });

  describe('buildPolicyObject', () => {
    it('emits only name and scope when no description or items are set', () => {
      expect(buildPolicyObject(baseState())).toEqual({ name: 'My Policy', scope: 'all' });
    });

    it('omits description when empty', () => {
      const result = buildPolicyObject({ ...baseState(), policyDescription: '' });

      expect(result).not.toHaveProperty('description');
    });

    it('includes description when non-empty', () => {
      const result = buildPolicyObject({ ...baseState(), policyDescription: 'hello' });

      expect(result.description).toBe('hello');
    });

    it('defaults scope to "all" when falsy', () => {
      expect(buildPolicyObject({ ...baseState(), scope: '' }).scope).toBe('all');
      expect(buildPolicyObject({ ...baseState(), scope: null }).scope).toBe('all');
    });

    it('omits empty triggers, rules, and actions arrays', () => {
      const result = buildPolicyObject(baseState());

      expect(result).not.toHaveProperty('triggers');
      expect(result).not.toHaveProperty('rules');
      expect(result).not.toHaveProperty('actions');
    });

    it('emits multiple triggers preserving order', () => {
      const result = buildPolicyObject({
        ...baseState(),
        triggers: ['merge_request_opened', 'report_published'],
        triggerConfigs: {
          report_published: { reportTypes: ['sast'], branchPattern: 'main' },
        },
      });

      expect(result.triggers).toEqual([
        { type: 'merge_request_opened' },
        { type: 'report_published', reportTypes: ['sast'], branchPattern: 'main' },
      ]);
    });

    it('drops empty string and null config values', () => {
      const result = buildPolicyObject({
        ...baseState(),
        rules: ['custom_rule'],
        ruleConfigs: { custom_rule: { name: 'foo', empty: '', missing: null, kept: 0 } },
      });

      expect(result.rules).toEqual([{ type: 'custom_rule', name: 'foo', kept: 0 }]);
    });

    it('drops empty arrays in config but keeps non-empty arrays', () => {
      const result = buildPolicyObject({
        ...baseState(),
        rules: ['rule_a'],
        ruleConfigs: { rule_a: { tags: [], owners: ['me'] } },
      });

      expect(result.rules).toEqual([{ type: 'rule_a', owners: ['me'] }]);
    });
  });

  describe('require_approval action transform', () => {
    const buildAction = (config) =>
      buildPolicyObject({
        ...baseState(),
        actions: ['require_approval'],
        actionConfigs: { require_approval: config },
      }).actions[0];

    it('splits approverGroups into group_approvers and user_approvers by @ prefix', () => {
      const action = buildAction({
        approverGroups: 'security-team, @alice, compliance, @bob',
      });

      expect(action).toEqual({
        type: 'require_approval',
        group_approvers: ['security-team', 'compliance'],
        user_approvers: ['alice', 'bob'],
      });
    });

    it('omits group_approvers when only users are listed', () => {
      const action = buildAction({ approverGroups: '@alice, @bob' });

      expect(action).toEqual({
        type: 'require_approval',
        user_approvers: ['alice', 'bob'],
      });
    });

    it('omits user_approvers when only groups are listed', () => {
      const action = buildAction({ approverGroups: 'team-a, team-b' });

      expect(action).toEqual({
        type: 'require_approval',
        group_approvers: ['team-a', 'team-b'],
      });
    });

    it('skips blank entries from the approverGroups text', () => {
      const action = buildAction({ approverGroups: 'team-a, , @alice,  ' });

      expect(action.group_approvers).toEqual(['team-a']);
      expect(action.user_approvers).toEqual(['alice']);
    });

    it('parses approvalCount as integer', () => {
      const action = buildAction({ approvalCount: '3' });

      expect(action.approvals_required).toBe(3);
      expect(action).not.toHaveProperty('approvalCount');
    });

    it('omits approvals_required when approvalCount is unparseable', () => {
      const action = buildAction({ approvalCount: 'not a number' });

      expect(action).not.toHaveProperty('approvals_required');
      expect(action).not.toHaveProperty('approvalCount');
    });

    it('renames requestMessage to request_message', () => {
      const action = buildAction({ requestMessage: 'Please review' });

      expect(action.request_message).toBe('Please review');
      expect(action).not.toHaveProperty('requestMessage');
    });

    it('drops UI keys entirely from emitted action', () => {
      const action = buildAction({
        approverGroups: 'team-a',
        approvalCount: '2',
        requestMessage: 'hi',
      });

      expect(action).not.toHaveProperty('approverGroups');
      expect(action).not.toHaveProperty('approvalCount');
      expect(action).not.toHaveProperty('requestMessage');
    });
  });

  describe('buildPolicyYaml', () => {
    it('produces parseable YAML round-trippable via safeLoad', () => {
      const yaml = buildPolicyYaml({
        ...baseState(),
        policyName: 'Round Trip',
        policyDescription: 'desc',
        rules: ['custom_rule'],
        ruleConfigs: { custom_rule: { name: 'foo' } },
      });

      expect(safeLoad(yaml)).toEqual({
        name: 'Round Trip',
        description: 'desc',
        scope: 'all',
        rules: [{ type: 'custom_rule', name: 'foo' }],
      });
    });

    it('emits multiline string fields as YAML block scalars', () => {
      const yaml = buildPolicyYaml({
        ...baseState(),
        rules: ['rego'],
        ruleConfigs: {
          rego: { policy: 'package policy\n\ndefault allow := false\n' },
        },
      });

      expect(safeLoad(yaml).rules[0].policy).toBe('package policy\n\ndefault allow := false\n');
    });
  });
});
