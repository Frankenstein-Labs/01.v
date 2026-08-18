import { GlProgressBar } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TotalFrameworkCoverage from 'ee/compliance_dashboard/components/dashboard/total_framework_coverage.vue';

describe('Total framework coverage panel', () => {
  let wrapper;

  function createComponent({ totalProjects = 0, coveredCount = 0 } = {}) {
    wrapper = shallowMountExtended(TotalFrameworkCoverage, {
      propsData: {
        summary: {
          totalProjects,
          coveredCount,
          details: [],
          groupId: 'gid://gitlab/Group/1',
        },
      },
    });
  }

  const findPercent = () => wrapper.findByTestId('total-coverage-percent');
  const findProgressBar = () => wrapper.findComponent(GlProgressBar);

  it('renders the coverage as a rounded percentage', () => {
    createComponent({ totalProjects: 40, coveredCount: 15 });

    expect(findPercent().text()).toMatchInterpolatedText('38%');
  });

  it('renders 0% when there are no projects', () => {
    createComponent();

    expect(findPercent().text()).toMatchInterpolatedText('0%');
  });

  it('renders a progress bar reflecting covered projects', () => {
    createComponent({ totalProjects: 40, coveredCount: 15 });

    expect(findProgressBar().props()).toMatchObject({ value: 15, max: 40 });
  });

  it('avoids a zero max on the progress bar when there are no projects', () => {
    createComponent();

    expect(findProgressBar().props('max')).toBe(1);
  });
});
