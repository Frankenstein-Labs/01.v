import { GlButton, GlButtonGroup, GlCollapse, GlPopover } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import CodeFlowStepsSection from 'ee/vue_shared/components/code_flow/code_flow_steps_section.vue';
import { mockVulnerability } from 'ee_jest/vulnerabilities/mock_data';

describe('Vulnerability Code Flow', () => {
  let wrapper;

  const createWrapper = (vulnerabilityOverrides) => {
    const propsData = {
      details: mockVulnerability.details,
      rawTextBlobs: mockVulnerability.rawTextBlobs,
      ...vulnerabilityOverrides,
    };
    wrapper = mountExtended(CodeFlowStepsSection, {
      propsData,
    });
  };

  const getById = (id) => wrapper.findByTestId(id);
  const getText = (id) => getById(id).text();
  const findAllPopovers = () => wrapper.findAllComponents(GlPopover);
  const findAllCollapses = () => wrapper.findAllComponents(GlCollapse);
  const findButtonGroup = () => wrapper.findComponent(GlButtonGroup);
  const findButtons = () => findButtonGroup().findAllComponents(GlButton);

  beforeEach(() => {
    createWrapper();
  });

  it('shows the properties that should always be shown', () => {
    expect(getById('source').exists()).toBe(true);
    expect(getById('sink').exists()).toBe(true);
    expect(getById('steps-header').exists()).toBe(true);
    expect(findAllPopovers().exists()).toBe(true);
    expect(findAllPopovers().exists()).toBe(true);
    expect(findButtonGroup().exists()).toBe(true);
    expect(findButtons().exists()).toBe(true);
    expect(findButtons()).toHaveLength(2);
  });

  describe('check popovers content', () => {
    it('checks all popovers data', () => {
      expect(findAllPopovers().at(0).props('content')).toContain(
        "A 'source' refers to untrusted inputs like user data",
      );
      expect(findAllPopovers().at(1).props('content')).toContain(
        "A 'sink' is where untrusted data is used in a potentially risky way",
      );
    });

    it('shows `Trace Entry Point` label and unverified source popover note when `isUnverifiedSource` is true', () => {
      createWrapper({ isUnverifiedSource: true });

      expect(getById('source').text()).toBe('Trace Entry Point');
      expect(findAllPopovers().at(0).props('content')).toBe(
        "This vulnerability was found but couldn't be traced back to the untrusted input that caused it. The root cause isn't fully understood, so review it carefully before making changes.",
      );
    });
  });

  it('shows the steps header test', () => {
    expect(getText('steps-header')).toBe(`3 steps across 1 files`);
  });

  it('check that collapse is visible by default', async () => {
    await nextTick();
    findAllCollapses().wrappers.forEach((collapseWrapper) => {
      expect(collapseWrapper.props('visible')).toBe(true);
    });
  });

  it('moves back and forward correctly', async () => {
    const steps = wrapper.vm.numOfSteps;
    const findBackButton = findButtons().wrappers[0];
    const findForwardButton = findButtons().wrappers[1];

    expect(findBackButton.attributes('aria-disabled')).toBe('true');
    expect(findForwardButton.attributes('aria-disabled')).toBeUndefined();

    for (let step = 1; step < steps; step += 1) {
      // eslint-disable-next-line no-await-in-loop
      await findForwardButton.trigger('click');

      if (step < steps - 1) {
        // intermediate steps: both buttons should be enabled
        expect(findBackButton.attributes('aria-disabled')).toBeUndefined();
        expect(findForwardButton.attributes('aria-disabled')).toBeUndefined();
      } else {
        // last step: forward button should be disabled, back button should be enabled
        expect(findBackButton.attributes('aria-disabled')).toBeUndefined();
        expect(findForwardButton.attributes('aria-disabled')).toBe('true');
      }
    }
  });

  describe('check step row', () => {
    let files;
    let rows;

    beforeEach(() => {
      files = wrapper.findAll('[data-testid^="file-steps-"]');
      rows = wrapper.findAll('[data-testid^="step-row-"]');
    });

    it('selects first row', () => {
      expect(files).toHaveLength(1);
      expect(rows).toHaveLength(3);

      files.wrappers.forEach((file, index) => {
        const fileRows = file.findAll('[data-testid^="step-row-"]');
        fileRows.wrappers.forEach((row, i) => {
          if (i === 0 && index === 0) {
            expect(row.classes()).toContain('gl-bg-blue-50');
          } else {
            expect(row.classes()).not.toContain('gl-bg-blue-50');
          }
        });
      });
    });

    it('validate data under each row', () => {
      let globalIndex = 0;

      files.wrappers.forEach((file) => {
        const fileRows = file.findAll('[data-testid^="step-row-"]');
        const firstNode = 0;
        const lastNode = fileRows.length - 1;

        fileRows.wrappers.forEach((row, index) => {
          globalIndex += 1;

          const componentsUnderRow = row.text();
          expect(componentsUnderRow).toContain(`${globalIndex}`);
          expect(componentsUnderRow).toContain(
            `${mockVulnerability.details.items[0][globalIndex - 1].fileLocation.lineStart}`,
          );
          expect(componentsUnderRow).toContain(
            `${mockVulnerability.details.items[0][globalIndex - 1].fileDescription}`,
          );
          if (index === firstNode || index === lastNode) {
            expect(componentsUnderRow).toContain(
              `${mockVulnerability.details.items[0][globalIndex - 1].nodeType}`,
            );
          }
        });
      });
    });
  });

  it('should show file name', () => {
    const fileName = 'src/url/test.java';
    expect(
      getById('file-name-0')
        .text()
        .replace(/\u200E/gi, ''), // remove truncate marks
    ).toBe(fileName);
  });

  it('should show escaped file name', () => {
    const fileName = 'app/<svg><use href="assets/icons-123.svg"/></svg>.py';
    const escapedFileName = 'app/<svg><use href="assets/icons-123.svg"/></svg>.py';

    createWrapper({
      details: {
        name: mockVulnerability.details.name,
        type: mockVulnerability.details.type,
        items: [
          [
            {
              ...mockVulnerability.details.items[0][0],
              fileLocation: {
                fileName,
                lineStart: mockVulnerability.details.items[0][0].fileLocation.lineStart,
              },
            },
          ],
        ],
      },
    });

    expect(
      getById('file-name-0')
        .text()
        .replace(/\u200E/gi, ''), // remove truncate marks
    ).toBe(escapedFileName);
  });
});
