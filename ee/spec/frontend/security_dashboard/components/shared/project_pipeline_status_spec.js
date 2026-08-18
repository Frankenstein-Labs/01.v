import { GlLink } from '@gitlab/ui';
import { merge } from 'lodash-es';
import { shallowMount } from '@vue/test-utils';
import PipelineStatusBadge from 'ee/security_dashboard/components/shared/pipeline_status_badge.vue';
import ProjectPipelineStatus from 'ee/security_dashboard/components/shared/project_pipeline_status.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { DEFAULT_DATE_TIME_FORMAT } from '~/lib/utils/datetime/locale_dateformat';

const defaultPipeline = {
  createdAt: '2020-10-06T20:08:07Z',
  id: '214',
  path: '/mixed-vulnerabilities/dependency-list-test-01/-/pipelines/214',
};

const emptySbomPipeline = {
  id: null,
};

const sbomPipeline = {
  createdAt: '2021-09-05T20:08:07Z',
  id: '245',
  path: '/mixed-vulnerabilities/dependency-list-test-01/-/pipelines/245',
};

describe('Project Pipeline Status Component', () => {
  let wrapper;

  const findPipelineStatusBadge = () =>
    wrapper.findByTestId('pipeline').findComponent(PipelineStatusBadge);
  const findTimeAgoTooltip = () => wrapper.findByTestId('pipeline').findComponent(TimeAgoTooltip);
  const findLink = () => wrapper.findByTestId('pipeline').findComponent(GlLink);
  const findPipelineDivider = () => wrapper.findByTestId('pipeline-divider');
  const findSbomPipelineContainer = () => wrapper.findByTestId('sbom-pipeline');
  const findSbomPipelineStatusBadge = () =>
    findSbomPipelineContainer().findComponent(PipelineStatusBadge);
  const findSbomTimeAgoTooltip = () => findSbomPipelineContainer().findComponent(TimeAgoTooltip);
  const findSbomLink = () => findSbomPipelineContainer().findComponent(GlLink);
  const findParsingStatusNotice = () => wrapper.findByTestId('parsing-status-notice');

  const createWrapper = (options = {}) => {
    wrapper = extendedWrapper(
      shallowMount(
        ProjectPipelineStatus,
        merge(
          {
            propsData: {
              pipeline: defaultPipeline,
              sbomPipeline: emptySbomPipeline,
            },
          },
          options,
        ),
      ),
    );
  };

  describe('default state', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should show the timeAgoTooltip component', () => {
      const TimeComponent = findTimeAgoTooltip();
      expect(TimeComponent.exists()).toBe(true);
      expect(TimeComponent.props()).toStrictEqual({
        time: defaultPipeline.createdAt,
        cssClass: '',
        enableTruncation: false,
        href: '',
        showDateWhenOverAYear: true,
        dateTimeFormat: DEFAULT_DATE_TIME_FORMAT,
        tooltipPlacement: 'top',
      });
    });

    it('should show the link component', () => {
      const GlLinkComponent = findLink();
      expect(GlLinkComponent.exists()).toBe(true);
      expect(GlLinkComponent.text()).toBe(`#${defaultPipeline.id}`);
      expect(GlLinkComponent.attributes('href')).toBe(defaultPipeline.path);
    });

    it('should show the pipeline status badge component', () => {
      expect(findPipelineStatusBadge().props('pipeline')).toBe(defaultPipeline);
    });

    it('should not show sbom pipeline status if it has no id', () => {
      expect(findPipelineDivider().exists()).toBe(false);
      expect(findSbomPipelineContainer().exists()).toBe(false);
    });
  });

  describe('parsing errors', () => {
    it('does not show a notice if there are no parsing errors', () => {
      createWrapper();

      expect(findParsingStatusNotice().exists()).toBe(false);
    });

    it.each`
      hasParsingErrors | hasParsingWarnings | expectedMessage
      ${true}          | ${true}            | ${'Parsing errors and warnings in pipeline'}
      ${true}          | ${false}           | ${'Parsing errors in pipeline'}
      ${false}         | ${true}            | ${'Parsing warnings in pipeline'}
    `(
      'shows a notice if there are parsing errors',
      ({ hasParsingErrors, hasParsingWarnings, expectedMessage }) => {
        createWrapper({
          propsData: {
            pipeline: { hasParsingErrors, hasParsingWarnings },
          },
        });
        const parsingStatus = findParsingStatusNotice();

        expect(parsingStatus.exists()).toBe(true);
        expect(parsingStatus.text()).toBe(expectedMessage);
      },
    );
  });

  describe('has sbom pipeline data', () => {
    beforeEach(() => {
      createWrapper({ propsData: { sbomPipeline } });
    });

    it('should display the pipeline divider as visible', () => {
      expect(findPipelineDivider().isVisible()).toBe(true);
    });

    it('should show the timeAgoTooltip component', () => {
      const TimeComponent = findSbomTimeAgoTooltip();
      expect(TimeComponent.exists()).toBe(true);
      expect(TimeComponent.props()).toStrictEqual({
        time: sbomPipeline.createdAt,
        cssClass: '',
        enableTruncation: false,
        href: '',
        showDateWhenOverAYear: true,
        dateTimeFormat: DEFAULT_DATE_TIME_FORMAT,
        tooltipPlacement: 'top',
      });
    });

    it('should show the link component', () => {
      const GlLinkComponent = findSbomLink();
      expect(GlLinkComponent.exists()).toBe(true);
      expect(GlLinkComponent.text()).toBe(`#${sbomPipeline.id}`);
      expect(GlLinkComponent.attributes('href')).toBe(sbomPipeline.path);
    });

    it('should show the pipeline status badge component', () => {
      expect(findSbomPipelineStatusBadge().props('pipeline')).toMatchObject(sbomPipeline);
    });
  });
});
