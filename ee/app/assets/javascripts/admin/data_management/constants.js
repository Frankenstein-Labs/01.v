import { GlFilteredSearchToken } from '@gitlab/ui';
import { SORT_DIRECTION } from 'ee/geo_shared/constants';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';

export const GEO_TROUBLESHOOTING_LINK = helpPagePath(
  'administration/geo/replication/troubleshooting/_index.md',
);

export const ACTION_TYPES = {
  CHECKSUM: 'checksum',
};

export const TOKEN_TYPES = {
  IDENTIFIERS: 'identifiers',
  MODEL: 'model_name',
  CHECKSUM_STATE: 'checksum_state',
};

export const CHECKSUM_STATES_ARRAY = [
  {
    title: s__('Geo|Pending'),
    value: 'pending',
  },
  {
    title: s__('Geo|Started'),
    value: 'started',
  },
  {
    title: s__('Geo|Succeeded'),
    value: 'succeeded',
  },
  {
    title: s__('Geo|Failed'),
    value: 'failed',
  },
  {
    title: s__('Geo|Disabled'),
    value: 'disabled',
  },
];

export const FILTERED_SEARCH_TOKEN_OPTIONS = [
  {
    title: s__('Geo|Checksum status'),
    type: TOKEN_TYPES.CHECKSUM_STATE,
    icon: 'check-circle',
    token: GlFilteredSearchToken,
    operators: OPERATORS_IS,
    unique: true,
    options: CHECKSUM_STATES_ARRAY,
  },
];

export const BULK_ACTIONS = [
  {
    id: 'geo-bulk-action-checksum',
    action: ACTION_TYPES.CHECKSUM,
    text: s__('Geo|Checksum all'),
    modal: {
      title: s__('Geo|Checksum all %{type}'),
      description: s__(
        'Geo|This will recalculate checksums for all %{type}. It may take some time to complete. Are you sure you want to continue?',
      ),
    },
    successMessage: s__('Geo|Scheduled all %{type} for checksum recalculation.'),
    errorMessage: s__('Geo|There was an error scheduling all %{type} for checksum recalculation.'),
  },
];

const SORT_OPTIONS = {
  ID: {
    text: s__('Geo|Model ID'),
    value: 'id',
  },
};

export const DEFAULT_SORT = {
  value: SORT_OPTIONS.ID.value,
  direction: SORT_DIRECTION.ASC,
};

export const SORT_OPTIONS_ARRAY = Object.values(SORT_OPTIONS);
