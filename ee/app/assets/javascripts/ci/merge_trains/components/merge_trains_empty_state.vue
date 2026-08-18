<script>
import { GlEmptyState, GlSprintf, GlLink } from '@gitlab/ui';
import MergeTrainSvg from '@gitlab/svgs/dist/illustrations/train-sm.svg?url';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';

export default {
  name: 'MergeTrainsEmptyState',
  components: {
    GlEmptyState,
    GlSprintf,
    GlLink,
  },
  inject: {
    projectName: {
      default: '',
    },
  },
  props: {
    branch: {
      type: String,
      required: true,
    },
  },
  MergeTrainSvg,
  docsLink: helpPagePath('ci/pipelines/merge_trains', { anchor: 'start-a-merge-train' }),
  message: s__(
    'Pipelines|There are no merge trains for the %{branch} target branch in %{projectName}. Merge requests added to a merge train are displayed on this page. Go to a merge request to %{linkStart}start a merge train.%{linkEnd}',
  ),
};
</script>

<template>
  <gl-empty-state :title="s__('Pipelines|No merge trains')" :svg-path="$options.MergeTrainSvg">
    <template #description>
      <div class="gl-leading-20">
        <gl-sprintf :message="$options.message">
          <template #branch>
            <code>{{ branch }}</code>
          </template>
          <template #projectName>
            <code>{{ projectName }}</code>
          </template>
          <template #link="{ content }">
            <gl-link :href="$options.docsLink">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </div>
    </template>
  </gl-empty-state>
</template>
