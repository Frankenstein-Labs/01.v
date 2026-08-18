import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AttributeScopesList from 'ee/security_orchestration/components/scope/attribute_scopes_list.vue';
import ToggleList from 'ee/security_orchestration/components/scope/toggle_list.vue';

const businessImpact = {
  category: { key: 'business_impact', name: 'Business Impact', templateType: 'BUSINESS_IMPACT' },
  including: [
    { id: 1, name: 'Mission Critical' },
    { id: 2, name: 'Business Critical' },
  ],
  includingCount: 2,
  excluding: [],
  excludingCount: 0,
};
const application = {
  category: { key: 'application', name: 'Application', templateType: 'APPLICATION' },
  including: [{ id: 10, name: 'Web app' }],
  includingCount: 1,
  excluding: [{ id: 11, name: 'Legacy app' }],
  excludingCount: 1,
};
const exposure = {
  category: { key: 'exposure', name: 'Exposure level', templateType: 'EXPOSURE' },
  including: [],
  includingCount: 0,
  excluding: [{ id: 3, name: 'Internet' }],
  excludingCount: 1,
};
// Two attributes loaded but five exist server-side (connection `count`).
const businessImpactTruncated = {
  category: { key: 'business_impact', name: 'Business Impact', templateType: 'BUSINESS_IMPACT' },
  including: [
    { id: 1, name: 'Mission Critical' },
    { id: 2, name: 'Business Critical' },
  ],
  includingCount: 5,
  excluding: [{ id: 3, name: 'Low' }],
  excludingCount: 4,
};

describe('AttributeScopesList', () => {
  let wrapper;

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(AttributeScopesList, { propsData });
  };

  describe('drawer mode (compact=false, default)', () => {
    const findSections = () => wrapper.findAllByTestId('attribute-scope-section');
    const findCategoryHeadings = () => wrapper.findAllByTestId('attribute-scope-category');
    const findIncludingIn = (section) => section.find('[data-testid="attribute-scope-including"]');
    const findExcludingIn = (section) => section.find('[data-testid="attribute-scope-excluding"]');
    const findIncludingMore = (section) =>
      section.find('[data-testid="attribute-scope-including-more"]');
    const findExcludingMore = (section) =>
      section.find('[data-testid="attribute-scope-excluding-more"]');

    it('renders one section per category that has any attributes', () => {
      createComponent({ attributeScopes: [businessImpact, exposure, application] });

      expect(findSections()).toHaveLength(3);
      expect(findCategoryHeadings().wrappers.map((w) => w.text())).toEqual([
        'Business Impact',
        'Exposure level',
        'Application',
      ]);
    });

    it('skips categories with no including and no excluding attributes', () => {
      const emptyCategory = {
        category: { key: 'business_unit', name: 'Business Unit', templateType: 'BUSINESS_UNIT' },
        including: [],
        excluding: [],
      };
      createComponent({ attributeScopes: [businessImpact, emptyCategory] });

      expect(findSections()).toHaveLength(1);
      expect(findCategoryHeadings().at(0).text()).toBe('Business Impact');
    });

    it('renders including attribute names in a bullet ToggleList under the "Including:" label', () => {
      createComponent({ attributeScopes: [businessImpact] });

      const section = findSections().at(0);
      const includingWrapper = findIncludingIn(section);
      expect(includingWrapper.text()).toContain('Including:');
      const toggleList = includingWrapper.findComponent(ToggleList);
      expect(toggleList.props('items')).toEqual(['Mission Critical', 'Business Critical']);
      expect(toggleList.props('bulletStyle')).toBe(true);
      expect(findExcludingIn(section).exists()).toBe(false);
    });

    it('renders excluding attribute names in a bullet ToggleList under the "Excluding:" label', () => {
      createComponent({ attributeScopes: [exposure] });

      const section = findSections().at(0);
      const excludingWrapper = findExcludingIn(section);
      expect(findIncludingIn(section).exists()).toBe(false);
      expect(excludingWrapper.text()).toContain('Excluding:');
      const toggleList = excludingWrapper.findComponent(ToggleList);
      expect(toggleList.props('items')).toEqual(['Internet']);
      expect(toggleList.props('bulletStyle')).toBe(true);
    });

    it('renders both including and excluding ToggleLists for a category that has both', () => {
      createComponent({ attributeScopes: [application] });

      const section = findSections().at(0);
      expect(findIncludingIn(section).findComponent(ToggleList).props('items')).toEqual([
        'Web app',
      ]);
      expect(findExcludingIn(section).findComponent(ToggleList).props('items')).toEqual([
        'Legacy app',
      ]);
    });

    it('renders the "Including:" and "Excluding:" labels in bold', () => {
      createComponent({ attributeScopes: [application] });

      const section = findSections().at(0);
      expect(findIncludingIn(section).find('p').classes()).toContain('gl-font-bold');
      expect(findExcludingIn(section).find('p').classes()).toContain('gl-font-bold');
    });

    it('renders a "+ N more" hint when more attributes exist than were loaded', () => {
      createComponent({ attributeScopes: [businessImpactTruncated] });

      const section = findSections().at(0);
      // 5 total - 2 loaded = 3, 4 total - 1 loaded = 3
      expect(findIncludingMore(section).text()).toBe('+ 3 more');
      expect(findExcludingMore(section).text()).toBe('+ 3 more');
    });

    it('does not render a "+ N more" hint when all attributes are loaded', () => {
      createComponent({ attributeScopes: [application] });

      const section = findSections().at(0);
      expect(findIncludingMore(section).exists()).toBe(false);
      expect(findExcludingMore(section).exists()).toBe(false);
    });
  });

  describe('list mode (compact=true)', () => {
    const findIncluding = () => wrapper.findByTestId('attribute-scope-including');
    const findExcluding = () => wrapper.findByTestId('attribute-scope-excluding');
    const findCategories = () => wrapper.findByTestId('attribute-scope-categories');
    const findCount = () => wrapper.findByTestId('attribute-scope-count');

    it('renders the aggregated including summary only', () => {
      createComponent({
        attributeScopes: [businessImpact, exposure, application],
        compact: true,
      });

      expect(findIncluding().exists()).toBe(true);
      expect(findExcluding().exists()).toBe(false);
    });

    it('joins category names that have including attributes with " · "', () => {
      createComponent({
        attributeScopes: [businessImpact, exposure, application],
        compact: true,
      });

      expect(findCategories().text()).toBe('Business Impact · Application');
    });

    it('aggregates the including count across categories with correct pluralization', () => {
      createComponent({
        attributeScopes: [businessImpact, application],
        compact: true,
      });

      // 2 (businessImpact) + 1 (application) = 3
      expect(findCount().text()).toBe('3 attributes');
    });

    it('uses singular form when total is 1', () => {
      createComponent({ attributeScopes: [application], compact: true });

      expect(findCount().text()).toBe('1 attribute');
    });

    it('counts the server-side total, not just the loaded attributes', () => {
      createComponent({ attributeScopes: [businessImpactTruncated], compact: true });

      // includingCount is 5 even though only 2 attributes were loaded
      expect(findCount().text()).toBe('5 attributes');
    });

    it('renders nothing when no category has including attributes', () => {
      createComponent({ attributeScopes: [exposure], compact: true });

      expect(findIncluding().exists()).toBe(false);
    });

    it('omits the "Including:" prefix', () => {
      createComponent({ attributeScopes: [businessImpact], compact: true });

      expect(findIncluding().text()).not.toContain('Including:');
    });
  });
});
