import {
  FIELD_TYPES,
  FIELD_TYPE_MULTI_BADGE,
  FIELD_TYPE_SELECT,
} from 'ee/policy_store/components/editor/constants';
import { ACTIONS } from 'ee/policy_store/catalog/actions';
import { CATEGORY_LABELS, CATEGORY_ORDER } from 'ee/policy_store/catalog/categories';
import { RULES } from 'ee/policy_store/catalog/rules';
import { TRIGGERS } from 'ee/policy_store/catalog/triggers';

// The catalog is data, and a typo in it fails silently: an unknown field `type` falls through to
// GenericConfig's text input, and a duplicated id shadows an entry. These assertions are the only
// thing standing between a mistyped catalog entry and a control that quietly renders wrong.
describe('policy store catalog', () => {
  describe.each([
    ['triggers', TRIGGERS],
    ['rules', RULES],
    ['actions', ACTIONS],
  ])('%s', (name, entries) => {
    it('is not empty', () => {
      expect(entries.length).toBeGreaterThan(0);
    });

    it('gives every entry a unique id', () => {
      const ids = entries.map(({ id }) => id);

      expect(new Set(ids).size).toBe(ids.length);
    });

    it('gives every entry an id, label, description, icon, category and fields', () => {
      entries.forEach((entry) => {
        expect(entry).toMatchObject({
          id: expect.any(String),
          label: expect.any(String),
          description: expect.any(String),
          icon: expect.any(String),
          category: expect.any(String),
          fields: expect.any(Array),
        });
      });
    });

    it('gives every field a unique key within its entry', () => {
      entries.forEach(({ fields }) => {
        const keys = fields.map(({ key }) => key);

        expect(new Set(keys).size).toBe(keys.length);
      });
    });

    // Category ids drive the drawer's grouping and sort order; the label map supplies
    // the displayed text. An id outside the order would sort unpredictably, and one
    // without a label would render as its raw id.
    it('gives every entry a category from the declared order, with a label', () => {
      entries.forEach(({ category }) => {
        expect(CATEGORY_ORDER).toContain(category);
        expect(CATEGORY_LABELS[category]).toEqual(expect.any(String));
      });
    });
  });

  // Flattened across all three catalogs: the field contract is the same wherever a field appears,
  // and triggers declare no fields, so asserting per-catalog would leave that block empty.
  describe('fields', () => {
    const allFields = [...TRIGGERS, ...RULES, ...ACTIONS].flatMap(({ fields }) => fields);

    it('has fields to check', () => {
      expect(allFields.length).toBeGreaterThan(0);
    });

    it('only uses field types GenericConfig can render', () => {
      allFields.forEach((field) => {
        expect(FIELD_TYPES).toContain(field.type);
      });
    });

    it('gives every field a key and a label', () => {
      allFields.forEach((field) => {
        expect(field).toMatchObject({ key: expect.any(String), label: expect.any(String) });
      });
    });

    it('gives every select and multi_badge field non-empty { id, label } options', () => {
      const withOptions = allFields.filter(({ type }) =>
        [FIELD_TYPE_SELECT, FIELD_TYPE_MULTI_BADGE].includes(type),
      );

      expect(withOptions.length).toBeGreaterThan(0);

      withOptions.forEach(({ options }) => {
        expect(options.length).toBeGreaterThan(0);
        options.forEach((option) => {
          expect(option).toMatchObject({ id: expect.any(String), label: expect.any(String) });
        });
      });
    });
  });

  describe('categories', () => {
    // The drawer renders its groups in exactly this sequence; reordering is a UX change
    // and should fail a test rather than slip through. Literals rather than the
    // imported constants, so a mistyped constant value cannot agree with itself.
    it('presents the groups in this exact order', () => {
      expect(CATEGORY_ORDER).toEqual([
        'enforcement',
        'advanced',
        'general',
        'deployment',
        'security',
        'process',
        'ai',
        'ci_cd',
        'code',
        'compliance',
        'access',
        'integrations',
      ]);
    });

    it('gives every labelled category a place in the order', () => {
      Object.keys(CATEGORY_LABELS).forEach((category) => {
        expect(CATEGORY_ORDER).toContain(category);
      });
    });
  });

  describe('scope', () => {
    it('ships exactly the CD deployment gate trigger', () => {
      expect(TRIGGERS.map(({ id }) => id)).toEqual(['deployment_requested']);
    });

    it('mirrors the backend rule catalog exactly', () => {
      // Gitlab::PolicyStore::Rules::ALL in the gitlab-policy-store gem; the ids are
      // the persisted wire values, so the frontend must not invent its own.
      expect(RULES.map(({ id }) => id)).toEqual(['custom', 'calendar', 'environment']);
    });

    it('ships only the two enforcement actions', () => {
      expect(ACTIONS.map(({ id }) => id)).toEqual(['block', 'require_approval']);
    });

    it('has no warn action, because warn is an enforcement mode', () => {
      expect(ACTIONS.map(({ id }) => id)).not.toContain('warn');
    });

    it('names the Rego rule `custom`, which is what the deployment gate reads back', () => {
      // EE::Ci::ProcessBuildService#rego_of finds `rule['type'] == 'custom'`.
      expect(RULES.map(({ id }) => id)).toContain('custom');
      expect(RULES.map(({ id }) => id)).not.toContain('rego');
    });
  });
});
