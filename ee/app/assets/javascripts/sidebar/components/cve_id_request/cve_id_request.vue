<script>
import { GlButton, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { mapState } from 'pinia';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createCveIdRequestIssueBody } from '~/helpers/cve_id_request_helper';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { useNotes } from '~/notes/store/legacy_notes';
import { CVE_ID_REQUEST_SIDEBAR_I18N } from '../../constants';

export default {
  name: 'CveIdRequest',
  i18n: {
    ...CVE_ID_REQUEST_SIDEBAR_I18N,
  },

  components: {
    GlButton,
    GlIcon,
    HelpIcon,
  },

  directives: {
    GlTooltip: GlTooltipDirective,
  },

  inject: {
    iid: {
      required: true,
      type: String,
    },
    fullPath: {
      required: true,
      type: String,
    },
  },

  data() {
    return {
      showHelp: false,
    };
  },

  computed: {
    ...mapState(useNotes, ['noteableData']),
    confidential() {
      return this.noteableData.confidential;
    },
    helpHref() {
      return helpPagePath('user/application_security/cve_id_request');
    },
    showHelpState() {
      return Boolean(this.showHelp);
    },
    tooltipTitle() {
      return this.$options.i18n.description;
    },
    newCveIdRequestUrl() {
      const currUrl = new URL(window.location.href);
      const newUrl = new URL(currUrl.origin);
      newUrl.pathname = '/gitlab-org/cves/-/issues/new';

      const params = {
        'issue[confidential]': 'true',
        // eslint-disable-next-line @gitlab/require-i18n-strings
        'issue[title]': `CVE ID Request - ${this.fullPath}`,
        'issue[description]': createCveIdRequestIssueBody(this.fullPath, this.iid),
      };
      Object.keys(params).forEach((k) => newUrl.searchParams.append(k, params[k]));

      return newUrl.toString();
    },
  },

  methods: {
    toggleHelpState(show) {
      this.showHelp = show;
    },
  },
};
</script>

<template>
  <div v-if="confidential" class="sidebar-contained-width cve-id-request gl-border-b-0 gl-pb-0">
    <div
      v-gl-tooltip.viewport.left
      :title="tooltipTitle"
      class="sidebar-collapsed-icon"
      data-container="body"
      data-placement="left"
      data-boundary="viewport"
    >
      <gl-icon name="bug" class="sidebar-item-icon is-active" />
    </div>

    <div class="hide-collapsed">
      {{ $options.i18n.action }}
      <div
        v-if="!showHelpState"
        class="help-button gl-float-right"
        data-testid="help-button"
        @click="toggleHelpState(true)"
      >
        <help-icon />
      </div>
      <div
        v-else
        class="close-help-button gl-float-right"
        data-testid="close-help-button"
        @click="toggleHelpState(false)"
      >
        <gl-icon name="close" />
      </div>

      <div class="gl-mt-5">
        <gl-button block :href="newCveIdRequestUrl" target="_blank" data-testid="request-button">{{
          $options.i18n.createRequest
        }}</gl-button>
      </div>

      <div class="hide-collapsed">
        <transition name="help-state-toggle">
          <div v-if="showHelpState" class="cve-id-request-help-state" data-testid="help-state">
            <h4>{{ $options.i18n.whyRequest }}</h4>
            <p>
              {{ $options.i18n.whyText1 }}
            </p>

            <p>
              {{ $options.i18n.whyText2 }}
            </p>

            <div>
              <gl-button :href="helpHref" target="_blank">{{ $options.i18n.learnMore }}</gl-button>
            </div>
          </div>
        </transition>
      </div>
    </div>
  </div>
</template>
