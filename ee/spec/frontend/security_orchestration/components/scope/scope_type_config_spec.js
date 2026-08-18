import AttributeScopesList from 'ee/security_orchestration/components/scope/attribute_scopes_list.vue';
import ComplianceFrameworksToggleList from 'ee/security_orchestration/components/scope/compliance_frameworks_toggle_list.vue';
import ProjectsToggleList from 'ee/security_orchestration/components/scope/projects_toggle_list.vue';
import GroupsToggleList from 'ee/security_orchestration/components/scope/groups_toggle_list.vue';
import ScopeDefaultLabel from 'ee/security_orchestration/components/scope/scope_default_label.vue';
import {
  resolveScopeType,
  normalizeAttributeScopes,
} from 'ee/security_orchestration/components/scope/scope_type_config';

const ctx = { isGroup: true, isInstanceLevel: false, linkedSppItems: [] };

const businessImpactAttribute = (overrides = {}) => ({
  id: 1,
  name: 'Mission Critical',
  securityCategory: { name: 'Business Impact', templateType: 'BUSINESS_IMPACT' },
  ...overrides,
});

const exposureAttribute = (overrides = {}) => ({
  id: 3,
  name: 'Internet Facing',
  securityCategory: { name: 'Exposure', templateType: 'EXPOSURE' },
  ...overrides,
});

const enableFlag = () => {
  window.gon = { ...window.gon, features: { securityAttributesPolicyScope: true } };
};

describe('resolveScopeType', () => {
  it.each`
    description                                | policyScope                                                                               | expectedComponent
    ${'compliance frameworks'}                 | ${{ complianceFrameworks: { nodes: [{ id: 1 }] } }}                                       | ${ComplianceFrameworksToggleList}
    ${'includingGroups only'}                  | ${{ includingGroups: { nodes: [{ id: 1 }] } }}                                            | ${GroupsToggleList}
    ${'compound (groups + excl projects)'}     | ${{ includingGroups: { nodes: [{ id: 1 }] }, excludingProjects: { nodes: [{ id: 2 }] } }} | ${GroupsToggleList}
    ${'compound (groups + incl projects)'}     | ${{ includingGroups: { nodes: [{ id: 1 }] }, includingProjects: { nodes: [{ id: 2 }] } }} | ${GroupsToggleList}
    ${'includingProjects'}                     | ${{ includingProjects: { nodes: [{ id: 1 }] } }}                                          | ${ProjectsToggleList}
    ${'excludingProjects with ids'}            | ${{ excludingProjects: { nodes: [{ id: 1 }] } }}                                          | ${ProjectsToggleList}
    ${'excludingPersonalProjects'}             | ${{ excludingPersonalProjects: true }}                                                    | ${ProjectsToggleList}
    ${'empty compliance frameworks nodes'}     | ${{ complianceFrameworks: { nodes: [] } }}                                                | ${ScopeDefaultLabel}
    ${'null-only nodes filtered to empty'}     | ${{ complianceFrameworks: { nodes: [null] } }}                                            | ${ScopeDefaultLabel}
    ${'empty groups + real excludingProjects'} | ${{ includingGroups: { nodes: [] }, excludingProjects: { nodes: [{ id: 1 }] } }}          | ${ProjectsToggleList}
    ${'empty includingProjects nodes'}         | ${{ includingProjects: { nodes: [] } }}                                                   | ${ScopeDefaultLabel}
    ${'no scope data'}                         | ${{}}                                                                                     | ${ScopeDefaultLabel}
    ${'null'}                                  | ${null}                                                                                   | ${ScopeDefaultLabel}
  `('$description → correct component (drawer)', ({ policyScope, expectedComponent }) => {
    expect(resolveScopeType(policyScope, 'drawer', ctx).component).toBe(expectedComponent);
  });

  it('compound: includingGroups entry receives excludingProjects in props', () => {
    const scope = {
      includingGroups: { nodes: [{ id: 1 }] },
      excludingProjects: { nodes: [{ id: 2 }] },
    };
    const { props } = resolveScopeType(scope, 'drawer', ctx);
    expect(props.groups).toEqual([{ id: 1 }]);
    expect(props.projects).toEqual([{ id: 2 }]);
  });

  it('list variant adds labelsToShow: 2 for compliance frameworks', () => {
    const scope = { complianceFrameworks: { nodes: [{ id: 1 }] } };
    expect(resolveScopeType(scope, 'list', ctx).props.labelsToShow).toBe(2);
  });

  it('drawer variant does not add labelsToShow for compliance frameworks', () => {
    const scope = { complianceFrameworks: { nodes: [{ id: 1 }] } };
    expect(resolveScopeType(scope, 'drawer', ctx).props.labelsToShow).toBeUndefined();
  });

  it('excludingPersonalProjects sets excludingPersonalProjects=true, projects=[]', () => {
    const scope = { excludingPersonalProjects: true };
    const { props } = resolveScopeType(scope, 'drawer', ctx);
    expect(props.excludingPersonalProjects).toBe(true);
    expect(props.projects).toEqual([]);
  });

  it('passes isInstanceLevel to ProjectsToggleList', () => {
    const scope = { includingProjects: { nodes: [{ id: 1 }] } };
    const { props } = resolveScopeType(scope, 'drawer', { ...ctx, isInstanceLevel: true });
    expect(props.isInstanceLevel).toBe(true);
  });

  describe('list variant props', () => {
    it('includingGroups list passes inlineList and isLink', () => {
      const scope = { includingGroups: { nodes: [{ id: 1 }] } };
      const { props } = resolveScopeType(scope, 'list', ctx);
      expect(props.inlineList).toBe(true);
      expect(props.isLink).toBe(true);
      expect(props.groups).toEqual([{ id: 1 }]);
    });

    it('includingProjects list passes inlineList, bulletStyle, projectsToShow', () => {
      const scope = { includingProjects: { nodes: [{ id: 1 }] } };
      const { props } = resolveScopeType(scope, 'list', ctx);
      expect(props.inlineList).toBe(true);
      expect(props.bulletStyle).toBe(false);
      expect(props.projectsToShow).toBe(2);
      expect(props.including).toBe(true);
      expect(props.excludingPersonalProjects).toBe(false);
    });

    it('excludingProjects list passes inlineList, bulletStyle, projectsToShow', () => {
      const scope = { excludingProjects: { nodes: [{ id: 1 }] } };
      const { props } = resolveScopeType(scope, 'list', ctx);
      expect(props.inlineList).toBe(true);
      expect(props.bulletStyle).toBe(false);
      expect(props.projectsToShow).toBe(2);
      expect(props.including).toBe(false);
      expect(props.excludingPersonalProjects).toBe(false);
    });
  });

  it('throws on unknown variant', () => {
    const scope = { complianceFrameworks: { nodes: [{ id: 1 }] } };
    expect(() => resolveScopeType(scope, 'drwer', ctx)).toThrow(/Unknown scope variant/);
  });

  describe('attributeScopes', () => {
    afterEach(() => {
      window.gon = {};
    });

    it('falls through to ScopeDefaultLabel when feature flag is off, even with data', () => {
      const scope = {
        includingBusinessImpactAttributes: { nodes: [businessImpactAttribute()] },
      };
      expect(resolveScopeType(scope, 'drawer', ctx).component).toBe(ScopeDefaultLabel);
    });

    it('falls through when flag is on but all category connections are empty', () => {
      enableFlag();
      const scope = {
        includingBusinessImpactAttributes: { nodes: [] },
        excludingBusinessImpactAttributes: { nodes: [] },
        includingExposureAttributes: { nodes: [] },
        excludingExposureAttributes: { nodes: [] },
      };
      expect(resolveScopeType(scope, 'drawer', ctx).component).toBe(ScopeDefaultLabel);
    });

    it('routes to AttributeScopesList when flag is on and at least one category has data', () => {
      enableFlag();
      const scope = {
        includingBusinessImpactAttributes: { nodes: [businessImpactAttribute()] },
      };
      expect(resolveScopeType(scope, 'drawer', ctx).component).toBe(AttributeScopesList);
    });

    it('drawer variant passes attributeScopes only (full detail mode)', () => {
      enableFlag();
      const scope = {
        includingBusinessImpactAttributes: { nodes: [businessImpactAttribute()] },
      };
      const { props } = resolveScopeType(scope, 'drawer', ctx);
      expect(props.attributeScopes).toHaveLength(1);
      expect(props.compact).toBeUndefined();
    });

    it('list variant passes attributeScopes and compact: true', () => {
      enableFlag();
      const scope = {
        includingBusinessImpactAttributes: { nodes: [businessImpactAttribute()] },
      };
      const { props } = resolveScopeType(scope, 'list', ctx);
      expect(props.attributeScopes).toHaveLength(1);
      expect(props.compact).toBe(true);
    });

    it('groups multi-category data into one entry per category', () => {
      enableFlag();
      const scope = {
        includingBusinessImpactAttributes: { nodes: [businessImpactAttribute()] },
        excludingExposureAttributes: { nodes: [exposureAttribute()] },
      };
      const { props } = resolveScopeType(scope, 'drawer', ctx);
      expect(props.attributeScopes).toHaveLength(2);
      expect(props.attributeScopes.map((s) => s.category.name)).toEqual([
        'Business Impact',
        'Exposure',
      ]);
    });
  });

  describe('normalizeAttributeScopes', () => {
    it('returns [] for null / empty / no-attribute scopes', () => {
      expect(normalizeAttributeScopes(null)).toEqual([]);
      expect(normalizeAttributeScopes({})).toEqual([]);
      expect(
        normalizeAttributeScopes({
          includingBusinessImpactAttributes: { nodes: [] },
          excludingBusinessImpactAttributes: { nodes: [] },
        }),
      ).toEqual([]);
    });

    it('builds one entry per non-empty category, taking category from the first node', () => {
      const result = normalizeAttributeScopes({
        includingBusinessImpactAttributes: {
          nodes: [businessImpactAttribute({ id: 1 }), businessImpactAttribute({ id: 2 })],
        },
        excludingBusinessImpactAttributes: { nodes: [businessImpactAttribute({ id: 3 })] },
        includingExposureAttributes: { nodes: [exposureAttribute()] },
      });

      expect(result).toHaveLength(2);
      expect(result[0]).toMatchObject({
        category: { name: 'Business Impact', templateType: 'BUSINESS_IMPACT' },
        including: [expect.objectContaining({ id: 1 }), expect.objectContaining({ id: 2 })],
        excluding: [expect.objectContaining({ id: 3 })],
      });
      expect(result[1]).toMatchObject({
        category: { name: 'Exposure', templateType: 'EXPOSURE' },
        including: [expect.objectContaining({ id: 3 })],
        excluding: [],
      });
    });

    it('falls back to the field name as key when securityCategory is missing', () => {
      const result = normalizeAttributeScopes({
        includingApplicationAttributes: {
          nodes: [{ id: 7, name: 'X' }],
        },
      });
      expect(result).toHaveLength(1);
      expect(result[0].category).toEqual({
        key: 'includingApplicationAttributes',
        name: '',
        templateType: null,
      });
    });

    it('preserves the configured category order regardless of input order', () => {
      const result = normalizeAttributeScopes({
        includingExposureAttributes: { nodes: [exposureAttribute()] },
        includingBusinessImpactAttributes: { nodes: [businessImpactAttribute()] },
      });
      expect(result.map((s) => s.category.templateType)).toEqual(['BUSINESS_IMPACT', 'EXPOSURE']);
    });

    it('threads the connection count, which can exceed the loaded node count', () => {
      const result = normalizeAttributeScopes({
        includingBusinessImpactAttributes: {
          count: 5,
          nodes: [businessImpactAttribute({ id: 1 }), businessImpactAttribute({ id: 2 })],
        },
        excludingBusinessImpactAttributes: {
          count: 4,
          nodes: [businessImpactAttribute({ id: 3 })],
        },
      });

      expect(result[0]).toMatchObject({
        including: [expect.objectContaining({ id: 1 }), expect.objectContaining({ id: 2 })],
        includingCount: 5,
        excludingCount: 4,
      });
    });

    it('falls back to the loaded node count when count is absent', () => {
      const result = normalizeAttributeScopes({
        includingBusinessImpactAttributes: {
          nodes: [businessImpactAttribute({ id: 1 }), businessImpactAttribute({ id: 2 })],
        },
      });

      expect(result[0]).toMatchObject({ includingCount: 2, excludingCount: 0 });
    });
  });
});
