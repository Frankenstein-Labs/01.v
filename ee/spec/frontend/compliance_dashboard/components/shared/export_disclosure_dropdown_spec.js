import {
  GlButton,
  GlFormGroup,
  GlFormInput,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import ExportApp from 'ee/compliance_dashboard/components/shared/export_disclosure_dropdown.vue';

describe('ExportApp component', () => {
  let wrapper;

  const findGlDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDefaultDropdownTitle = () =>
    wrapper.findByText('Send email of the chosen report as CSV');
  const findViolationsExportButton = () => wrapper.findByText('Export violations report');
  const findFrameworksButton = () => wrapper.findByText('Export frameworks report');
  const findProjectFrameworksButton = () => wrapper.findByText('Export list of project frameworks');
  const findStandardsAdherenceReportButton = () =>
    wrapper.findByText('Export standards adherence report');
  const findComplianceStatusReportButton = () => wrapper.findByText('Export status report');
  const findChainOfCustodyReportButton = () => wrapper.findByText('Export chain of custody report');
  const findCustodyReportByCommmitButton = () =>
    wrapper.findByText('Export custody report of a specific commit');
  const findCustodyReportByCommitExportButton = () =>
    wrapper.findComponentByTestId('merge-commit-submit-button');
  const findCustodyReportByCommitCancelButton = () =>
    wrapper.findComponentByTestId('merge-commit-cancel-button');
  const findCommitInput = () => wrapper.findComponent(GlFormInput);
  const findCommitInputGroup = () => wrapper.findComponent(GlFormGroup);
  const findGlDisclosureDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);

  const createComponent = ({ props = {} } = {}) => {
    return shallowMountExtended(ExportApp, {
      propsData: {
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: {
        GlButton,
        GlDisclosureDropdown,
        GlDisclosureDropdownItem,
      },
    });
  };

  const expectTooltipText = (text, index = 0) => {
    const tooltip = getBinding(findGlDisclosureDropdownItems().at(index).element, 'gl-tooltip');
    expect(tooltip.value).toMatchObject({
      title: `${text} You will be emailed after the export is processed.`,
      boundary: 'viewport',
      customClass: 'gl-pointer-events-none',
      placement: 'left',
    });
  };

  describe('default behavior', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the dropdown button and content', () => {
      expect(findGlDisclosureDropdown().props('toggleText')).toBe('Export');
      expect(findDefaultDropdownTitle().exists()).toBe(true);
    });

    it('does not render prop-based dropdown items', () => {
      expect(findComplianceStatusReportButton().exists()).toBe(false);
      expect(findStandardsAdherenceReportButton().exists()).toBe(false);
      expect(findViolationsExportButton().exists()).toBe(false);
      expect(findFrameworksButton().exists()).toBe(false);
      expect(findProjectFrameworksButton().exists()).toBe(false);
      expect(findChainOfCustodyReportButton().exists()).toBe(false);
      expect(findCustodyReportByCommmitButton().exists()).toBe(false);
    });
  });

  describe.each`
    props                                                   | tooltipText                                                                               | tooltipIndex
    ${{ complianceStatusReportExportPath: 'example-path' }} | ${'Export contents of the status report as a CSV file.'}                                  | ${0}
    ${{ adherencesCsvExportPath: 'example-path' }}          | ${'Export contents of the standards adherence report as a CSV file.'}                     | ${0}
    ${{ violationsCsvExportPath: 'example-path' }}          | ${'Export merge request violations as a CSV file.'}                                       | ${0}
    ${{ frameworksCsvExportPath: 'example-path' }}          | ${'Export contents of the compliance frameworks report as a CSV file.'}                   | ${0}
    ${{ projectFrameworksCsvExportPath: 'example-path' }}   | ${'Export a list of compliance frameworks for a project as a CSV file.'}                  | ${0}
    ${{ mergeCommitsCsvExportPath: 'example-path' }}        | ${'Export chain of custody report as a CSV file (limited to 15MB).'}                      | ${0}
    ${{ mergeCommitsCsvExportPath: 'example-path' }}        | ${'Export chain of custody report of a specific commit as a CSV file (limited to 15MB).'} | ${1}
  `('when $props is passed in', ({ props, tooltipText, tooltipIndex }) => {
    beforeEach(() => {
      wrapper = createComponent({ props });
    });

    it('renders the correct export dropdown item with the correct tooltip text', () => {
      expectTooltipText(tooltipText, tooltipIndex);
    });
  });

  describe('when chain of custody report of a specific commit is clicked', () => {
    beforeEach(async () => {
      wrapper = createComponent({
        props: { mergeCommitsCsvExportPath: 'example-path' },
      });

      await findCustodyReportByCommmitButton().trigger('click');
    });

    it('changes the title and content of the dropdown disclosure', () => {
      expect(findDefaultDropdownTitle().exists()).toBe(false);
      expect(findCustodyReportByCommmitButton().exists()).toBe(true);
      expect(findCommitInputGroup().exists()).toBe(true);
      expect(findCustodyReportByCommitExportButton().exists()).toBe(true);
      expect(findCustodyReportByCommitCancelButton().exists()).toBe(true);
    });

    it('sets the placeholder', () => {
      expect(findCommitInput().attributes('placeholder')).toEqual('Example: 2dc6aa3');
    });

    describe('when the cancel button is clicked', () => {
      beforeEach(async () => {
        await findCustodyReportByCommitCancelButton().vm.$emit('click');
      });

      it('changes the title and content of the dropdown discloure back to default', () => {
        expect(findDefaultDropdownTitle().exists()).toBe(true);
        expect(findCustodyReportByCommmitButton().exists()).toBe(true);
        expect(findCommitInputGroup().exists()).toBe(false);
        expect(findCustodyReportByCommitExportButton().exists()).toBe(false);
        expect(findCustodyReportByCommitCancelButton().exists()).toBe(false);
      });
    });

    describe.each`
      scenario            | inputValue         | expectedFormGroupState | buttonDisabled
      ${'valid commit'}   | ${'123abc'}        | ${'true'}              | ${false}
      ${'invalid commit'} | ${'__invalidHash'} | ${undefined}           | ${true}
    `(
      'when the commit input is a $scenario',
      ({ inputValue, expectedFormGroupState, buttonDisabled }) => {
        beforeEach(async () => {
          await findCommitInput().vm.$emit('input', inputValue);
        });

        it('sets the appropriate validation state', () => {
          expect(findCommitInputGroup().attributes('state')).toBe(expectedFormGroupState);
        });

        it(`sets disabled prop as ${buttonDisabled} for the submit button`, () => {
          expect(findCustodyReportByCommitExportButton().props('disabled')).toBe(buttonDisabled);
        });
      },
    );
  });
});
