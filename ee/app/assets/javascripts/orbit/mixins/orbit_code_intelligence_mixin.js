import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';
import { joinPaths } from '~/lib/utils/url_utility';
import { executeOrbitQuery } from '../api/orbit_api';

export const DEFINITION_TYPE_ICONS = {
  Class: 'cube',
  Module: 'package',
  Method: 'code',
  SingletonMethod: 'code',
  Attribute: 'doc-text',
  Function: 'formula',
  Variable: 'doc-text',
  Struct: 'object',
};

export const DEFINITION_TYPE_VARIANTS = {
  Class: 'warning',
  Module: 'success',
  Method: 'info',
  SingletonMethod: 'info',
  Attribute: 'subtle',
  Function: 'success',
  Variable: 'subtle',
  Struct: 'warning',
};

/* eslint-disable @gitlab/require-i18n-strings */
export const DEFINITION_TYPE_ORDER = Object.freeze([
  'Class',
  'Module',
  'Method',
  'SingletonMethod',
  'Function',
  'Attribute',
  'Variable',
  'Struct',
]);

const ENTITY_FILE = 'File';
const ENTITY_DEFINITION = 'Definition';
const REL_DEFINES = 'DEFINES';
const REL_CALLS = 'CALLS';
const QUERY_TYPE = 'traversal';
const DEF_COLUMNS = Object.freeze(['start_line', 'file_path', 'name', 'fqn', 'definition_type']);
const SOURCE_TYPE = 'code_intelligence';
/* eslint-enable @gitlab/require-i18n-strings */

const ERROR_MSG = s__('Orbit|Failed to load code navigation data.');
const REFS_ERROR_MSG = s__('Orbit|Failed to load references.');
const LINE_LABEL_TEMPLATE = s__('Orbit|L%{line}');

export const buildDefinesQuery = (projectId, filePath) => ({
  query_type: QUERY_TYPE,
  nodes: [
    { id: 'file', entity: ENTITY_FILE, filters: { project_id: projectId, path: filePath } },
    { id: 'def', entity: ENTITY_DEFINITION, columns: DEF_COLUMNS },
  ],
  relationships: [{ type: REL_DEFINES, from: 'file', to: 'def' }],
  limit: 100,
});

export const buildCallersQuery = (projectId, filePath) => ({
  query_type: QUERY_TYPE,
  nodes: [
    { id: 'caller', entity: ENTITY_DEFINITION },
    {
      id: 'def',
      entity: ENTITY_DEFINITION,
      filters: { project_id: projectId, file_path: filePath },
    },
  ],
  relationships: [{ type: REL_CALLS, from: 'caller', to: 'def' }],
  limit: 500,
});

export const buildReferencesQuery = (nodeId) => ({
  query_type: QUERY_TYPE,
  nodes: [
    { id: 'caller', entity: ENTITY_DEFINITION, columns: DEF_COLUMNS },
    { id: 'def', entity: ENTITY_DEFINITION, node_ids: [nodeId] },
  ],
  relationships: [{ type: REL_CALLS, from: 'caller', to: 'def' }],
  limit: 100,
});

export const buildCalleesQuery = (nodeId) => ({
  query_type: QUERY_TYPE,
  nodes: [
    { id: 'caller', entity: ENTITY_DEFINITION, node_ids: [nodeId] },
    { id: 'callee', entity: ENTITY_DEFINITION, columns: DEF_COLUMNS },
  ],
  relationships: [{ type: REL_CALLS, from: 'caller', to: 'callee' }],
  limit: 100,
});

const groupByFile = (items) => {
  const byFile = {};
  items.forEach((item) => {
    if (!byFile[item.file_path]) byFile[item.file_path] = [];
    byFile[item.file_path].push(item);
  });
  return Object.entries(byFile).map(([filePath, refs]) => ({
    filePath,
    refs: [...refs].sort((a, b) => a.start_line - b.start_line),
  }));
};

export default {
  props: {
    projectId: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    currentRef: {
      type: String,
      required: true,
    },
    filePath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      loading: false,
      definitions: [],
      callerEdges: [],
      selectedDef: null,
      activeTab: 'references',
      references: [],
      loadingRefs: false,
      callees: [],
      loadingCallees: false,
    };
  },
  computed: {
    callerCountById() {
      const counts = {};
      this.callerEdges.forEach(({ to_id: toId }) => {
        counts[toId] = (counts[toId] || 0) + 1;
      });
      return counts;
    },
    sortedDefinitions() {
      return [...this.definitions].sort((a, b) => {
        const ai = DEFINITION_TYPE_ORDER.indexOf(a.definition_type);
        const bi = DEFINITION_TYPE_ORDER.indexOf(b.definition_type);
        return (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi);
      });
    },
    // Flat list of definitions with a `depth` value derived from FQN nesting,
    // e.g. `api.parseErrorResponse.errorMessage` renders one level deeper than
    // its parent `api.parseErrorResponse`. Walk children in the same order
    // that `sortedDefinitions` sorted their parents so the tree preserves
    // type ordering within each scope.
    definitionsTree() {
      const defs = this.sortedDefinitions;
      const byFqn = new Map(defs.filter((d) => d.fqn).map((d) => [d.fqn, d]));
      const childIds = new Set();
      const childrenByParentFqn = new Map();

      defs.forEach((d) => {
        if (!d.fqn) return;
        const segments = d.fqn.split('.');
        for (let i = segments.length - 1; i >= 1; i -= 1) {
          const candidate = segments.slice(0, i).join('.');
          const parent = byFqn.get(candidate);
          if (parent && parent.id !== d.id) {
            if (!childrenByParentFqn.has(candidate)) childrenByParentFqn.set(candidate, []);
            childrenByParentFqn.get(candidate).push(d);
            childIds.add(d.id);
            break;
          }
        }
      });

      const flat = [];
      const walk = (def, depth) => {
        flat.push({ def, depth });
        (childrenByParentFqn.get(def.fqn) || []).forEach((child) => walk(child, depth + 1));
      };
      defs.filter((d) => !childIds.has(d.id)).forEach((d) => walk(d, 0));
      return flat;
    },
    referencesByFile() {
      return groupByFile(this.references);
    },
    calleesByFile() {
      return groupByFile(this.callees);
    },
  },
  watch: {
    filePath: {
      immediate: true,
      handler() {
        this.selectedDef = null;
        this.references = [];
        this.fetchData();
      },
    },
  },
  methods: {
    async fetchData() {
      const projectId = getIdFromGraphQLId(this.projectId);
      if (!projectId || !this.filePath) return;

      this.loading = true;
      this.definitions = [];
      this.callerEdges = [];

      try {
        const [defResult, callersResult] = await Promise.all([
          executeOrbitQuery(buildDefinesQuery(projectId, this.filePath), {
            sourceType: SOURCE_TYPE,
          }),
          executeOrbitQuery(buildCallersQuery(projectId, this.filePath), {
            sourceType: SOURCE_TYPE,
          }),
        ]);

        const defNodes = defResult.data?.result?.nodes || [];
        this.definitions = defNodes.filter((n) => n.type === 'Definition');

        const callerData = callersResult.data?.result || {};
        this.callerEdges = (callerData.edges || []).filter((e) => e.type === 'CALLS');
      } catch {
        createAlert({ message: ERROR_MSG, variant: 'warning' });
      } finally {
        this.loading = false;
      }
    },
    async selectDef(def) {
      this.selectedDef = def;
      this.activeTab = 'references';
      this.references = [];
      this.callees = [];
      this.loadingRefs = true;
      this.loadingCallees = true;

      try {
        const [refsResult, calleesResult] = await Promise.all([
          executeOrbitQuery(buildReferencesQuery(def.id), { sourceType: SOURCE_TYPE }),
          executeOrbitQuery(buildCalleesQuery(def.id), { sourceType: SOURCE_TYPE }),
        ]);

        const refNodes = refsResult.data?.result?.nodes || [];
        // Exclude the target definition itself — the traversal response includes
        // both caller and def nodes, and def arrives without start_line.
        this.references = refNodes.filter((n) => n.type === 'Definition' && n.id !== def.id);

        const calleeNodes = calleesResult.data?.result?.nodes || [];
        this.callees = calleeNodes.filter((n) => n.type === 'Definition' && n.id !== def.id);
      } catch {
        createAlert({ message: REFS_ERROR_MSG, variant: 'warning' });
      } finally {
        this.loadingRefs = false;
        this.loadingCallees = false;
      }
    },
    clearSelection() {
      this.selectedDef = null;
      this.activeTab = 'references';
      this.references = [];
      this.callees = [];
    },
    typeIcon(type) {
      return DEFINITION_TYPE_ICONS[type] || 'code';
    },
    typeVariant(type) {
      return DEFINITION_TYPE_VARIANTS[type] || 'info';
    },
    callersFor(defId) {
      return this.callerCountById[defId] || 0;
    },
    // KG serves 1-indexed line numbers (see knowledge-graph!1452), matching
    // GitLab's blob anchors. startLine arrives as a string from the API.
    // `|| 1` (not `?? 1`) so a 0/empty value defaults to line 1 — KG doesn't
    // emit 0 today, but a stray 0 would produce an invalid `#L0` anchor.
    blobUrl(filePath, startLine) {
      if (!this.projectPath || !this.currentRef || filePath == null) return null;
      const line = Number(startLine) || 1;
      // eslint-disable-next-line @gitlab/no-hardcoded-urls
      return `${joinPaths(window.gon?.relative_url_root || '/', this.projectPath, '-', 'blob', this.currentRef, filePath)}#L${line}`;
    },
    projectSearchUrl(query) {
      if (!this.projectPath || !query) return null;
      // eslint-disable-next-line @gitlab/no-hardcoded-urls
      return `${joinPaths(window.gon?.relative_url_root || '/', this.projectPath, '-', 'search')}?scope=blobs&search=${encodeURIComponent(query)}`;
    },
    lineLabel(startLine) {
      return sprintf(LINE_LABEL_TEMPLATE, { line: Number(startLine) || 1 });
    },
  },
};
