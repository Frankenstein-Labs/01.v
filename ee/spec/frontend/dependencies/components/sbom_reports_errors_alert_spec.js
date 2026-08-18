import { GlAccordion, GlTruncate, GlAccordionItem, GlSprintf } from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SbomReportsErrorsAlert from 'ee/dependencies/components/sbom_reports_errors_alert.vue';

const TEST_ERRORS = [
  [{ message: 'Unsupported CycloneDX spec version. Must be one of: 1.4, 1.5', help_link: null }],
  [
    { message: 'Invalid CycloneDX report: property "/metadata/tools/0"', help_link: null },
    { message: 'Some other error', help_link: null },
  ],
];

const TEST_ERRORS_WITH_HELP_LINK = [
  [
    {
      message:
        'Required GitLab CycloneDX properties are missing. This will prevent vulnerability scanning and may result in incomplete license and package information.',
      help_link:
        'user/application_security/dependency_scanning/dependency_scanning_sbom/#bringing-your-own-sbom',
    },
  ],
];

const TEST_LEGACY_ERRORS = [
  ['Unsupported CycloneDX spec version. Must be one of: 1.4, 1.5'],
  ['Invalid CycloneDX report: property "/metadata/tools/0"', 'Some other error'],
];

describe('SbomReportsErrorsAlert component', () => {
  let wrapper;

  const createWrapper = ({ propsData } = {}) =>
    shallowMountExtended(SbomReportsErrorsAlert, {
      propsData: {
        errors: TEST_ERRORS,
        ...propsData,
      },
      stubs: {
        GlSprintf,
        GlTruncate,
      },
    });

  const findHelpPageLink = () => wrapper.findComponent(HelpPageLink);
  const findErrorListHelpPageLink = () =>
    wrapper
      .findAllComponents(HelpPageLink)
      .wrappers.find((w) => w.props('href') !== 'user/application_security/dependency_list/_index');
  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAllAccordionItems = () => wrapper.findAllComponents(GlAccordionItem);
  const findAccordionItemWithTitle = (title) =>
    findAllAccordionItems().wrappers.find((item) => item.props('title') === title);
  const findErrorList = () => wrapper.findByRole('list');
  const findSbomErrorDescription = () => wrapper.findByTestId('sbom-error-description');

  beforeEach(() => {
    wrapper = createWrapper();
  });

  it('links to the SBOM report documentation', () => {
    expect(findHelpPageLink().props()).toEqual({
      href: 'user/application_security/dependency_list/_index',
      anchor: 'set-up-the-dependency-list',
    });
  });

  describe('error description text', () => {
    it('renders the value provided via the props', () => {
      wrapper = createWrapper({ propsData: { errorDescription: 'custom description' } });

      expect(findSbomErrorDescription().text()).toBe('custom description');
    });

    it('renders the default value when none is provided', () => {
      const defaultDescription =
        'The following SBOM reports could not be parsed. Therefore the list of components may be incomplete.';

      expect(findSbomErrorDescription().text()).toBe(defaultDescription);
    });
  });

  describe('alert details', () => {
    it('shows an accordion containing a list of reports with errors', () => {
      expect(findAccordion().exists()).toBe(true);
      expect(findAllAccordionItems()).toHaveLength(TEST_ERRORS.length);
    });

    it('shows a list containing details about each message', () => {
      expect(findErrorList().exists()).toBe(true);
    });

    describe.each`
      errors            | title
      ${TEST_ERRORS[0]} | ${'report-1 (1)'}
      ${TEST_ERRORS[1]} | ${'report-2 (2)'}
    `('when errors are $errors', ({ errors, title }) => {
      it('contains an accordion item with the correct title', () => {
        expect(findAccordionItemWithTitle(title).exists()).toBe(true);
      });

      it('contains a detailed list of errors', () => {
        const expectedErrors = findAccordionItemWithTitle(title)
          .findAll('li')
          .wrappers.map((w) => w.text());

        expect(expectedErrors).toStrictEqual(errors.map((e) => e.message));
      });
    });
  });

  describe('error rendering with help link', () => {
    beforeEach(() => {
      wrapper = createWrapper({ propsData: { errors: TEST_ERRORS_WITH_HELP_LINK } });
    });

    it('renders a help link with the correct href', () => {
      const helpLink = findErrorListHelpPageLink();
      expect(helpLink.exists()).toBe(true);
      expect(helpLink.props('href')).toBe(
        'user/application_security/dependency_scanning/dependency_scanning_sbom/#bringing-your-own-sbom',
      );
    });

    it('renders the error message text', () => {
      expect(wrapper.text()).toContain('Required GitLab CycloneDX properties are missing');
    });
  });

  describe('legacy string error rendering', () => {
    beforeEach(() => {
      wrapper = createWrapper({ propsData: { errors: TEST_LEGACY_ERRORS } });
    });

    it('renders plain string errors without a help link', () => {
      expect(findErrorListHelpPageLink()).toBeUndefined();
      expect(wrapper.text()).toContain(
        'Unsupported CycloneDX spec version. Must be one of: 1.4, 1.5',
      );
    });
  });
});
