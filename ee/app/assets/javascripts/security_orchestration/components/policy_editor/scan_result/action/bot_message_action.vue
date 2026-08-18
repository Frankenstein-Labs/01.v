<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';
import SectionLayout from '../../section_layout.vue';
import { DISABLED_BOT_MESSAGE_ACTION } from '../lib';

export default {
  DISABLED_BOT_MESSAGE_ACTION,
  documentationLink: helpPagePath(
    'user/application_security/policies/merge_request_approval_policies',
    {
      anchor: 'example-bot-messages',
    },
  ),
  i18n: {
    contentText: s__(
      'SecurityOrchestration|%{boldStart}Send a bot message%{boldEnd} as comment to merge request creator.',
    ),
    linkText: s__('SecurityOrchestration|What does an example message look like?'),
  },
  name: 'BotCommentAction',
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    SectionLayout,
  },
  emits: ['changed'],
  methods: {
    remove() {
      this.$emit('changed', this.$options.DISABLED_BOT_MESSAGE_ACTION);
    },
  },
};
</script>

<template>
  <section-layout
    class="gl-pr-0 gl-pt-0"
    content-classes="gl-pt-5"
    :show-remove-button="true"
    @remove="remove"
  >
    <template #content>
      <div class="gl-mt-3 gl-flex-col">
        <gl-sprintf :message="$options.i18n.contentText">
          <template #bold="{ content }">
            <b>{{ content }}</b>
          </template>
        </gl-sprintf>
        <gl-link
          class="gl-mt-5 gl-block gl-min-w-fit"
          :href="$options.documentationLink"
          target="_blank"
        >
          <gl-icon name="information-o" />
          {{ $options.i18n.linkText }}
        </gl-link>
      </div>
    </template>
  </section-layout>
</template>
