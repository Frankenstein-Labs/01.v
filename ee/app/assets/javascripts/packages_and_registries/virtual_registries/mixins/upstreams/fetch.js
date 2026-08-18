import { createAlert } from '~/alert';
import { s__, n__ } from '~/locale';
import { getPageParams } from '~/packages_and_registries/shared/utils';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

const PAGE_SIZE = 20;
export const INITIAL_UPSTREAMS_PARAMS = {
  first: PAGE_SIZE,
};
const INITIAL_UPSTREAMS_VALUE = {
  nodes: [],
  pageInfo: {},
  count: null,
};

export default {
  inject: ['getUpstreamsQuery', 'getUpstreamsCountQuery'],
  apollo: {
    upstreams: {
      query() {
        return this.getUpstreamsQuery;
      },
      variables() {
        return this.queryVariables;
      },
      update: (data) => data.group?.upstreams ?? INITIAL_UPSTREAMS_VALUE,
      error(error) {
        createAlert({
          message: error.message || s__('VirtualRegistry|Failed to fetch list of upstreams.'),
        });
        captureException({ error, component: this.$options.name });
      },
    },
    upstreamsCount: {
      query() {
        return this.getUpstreamsCountQuery;
      },
      variables() {
        return this.queryVariables;
      },
      update: (data) => data.group?.upstreams?.count ?? null,
    },
  },
  data() {
    return {
      upstreamsSearchTerm: null,
      upstreamsPageParams: INITIAL_UPSTREAMS_PARAMS,
      upstreams: INITIAL_UPSTREAMS_VALUE,
      upstreamsCount: null,
    };
  },
  computed: {
    upstreamsTabCountSRText() {
      if (this.upstreamsCount === null) return '';

      return n__(
        'VirtualRegistry|%d upstream',
        'VirtualRegistry|%d upstreams',
        this.upstreamsCount,
      );
    },
    queryVariables() {
      return {
        groupPath: this.fullPath,
        upstreamName: this.upstreamsSearchTerm,
        ...this.upstreamsPageParams,
      };
    },
  },
  methods: {
    handleUpstreamsSearch(searchTerm) {
      this.upstreamsSearchTerm = searchTerm;
      this.upstreamsPageParams = INITIAL_UPSTREAMS_PARAMS;
    },
    handleUpstreamsPagination(params) {
      this.upstreamsPageParams = getPageParams(params, PAGE_SIZE);
    },
    handleUpstreamsDeleted() {
      this.$apollo.queries.upstreams.refetch();
      this.$apollo.queries.upstreamsCount.refetch();
    },
  },
};
