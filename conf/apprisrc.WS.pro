##########################################################
# SETTING UP ENVIRONMENT VARIABLES AND PERL LIBRARY PATH #
##########################################################

# ----------------------------------#
# Setting up vars of APPRIS program #
# ----------------------------------#

export APPRIS_HOME="/home/appris"

export APPRIS_WSERVER_HOME="${APPRIS_HOME}/ws"

. "${APPRIS_HOME}/code/conf/apprisrc"

# ----------------------------#
# Setting up vars for scripts #
# ----------------------------#

export APPRIS_SCRIPTS_DIR="${APPRIS_HOME}/scripts"

export APPRIS_SCRIPTS_BIN_DIR="${APPRIS_SCRIPTS_DIR}/bin"

export APPRIS_SCRIPTS_CONF_DIR="${APPRIS_SCRIPTS_DIR}/conf"

# ------------------------------------------#
# Setting up vars of workspaces directories #
# ------------------------------------------#

export APPRIS_WORKSPACE="${APPRIS_WSERVER_HOME}/tmp"

export APPRIS_WORKSPACE_LOG_DIR="${APPRIS_WORKSPACE}"

# --------------------------#
# Setting up features files #
# --------------------------#

export APPRIS_FEATURES_DIR="${APPRIS_WSERVER_HOME}/features"

# -----------------------------------#
# Setting up the vars for web server #
# -----------------------------------#

export APPRIS_WS_NAME="wserver"

#export APPRIS_SCRIPTS_CLUSTER_INI_WSERVER="${APPRIS_SCRIPTS_CONF_DIR}/cluster.ini.wserver"

export APPRIS_WSERVER_PIPELINE_STRUCTURE="firestar,matador3d,spade,corsair,thump,crash,appris"

export APPRIS_WSERVER_PIPELINE_STRUCTURE_SEQ="sequences,residues"

export APPRIS_WSERVER_PIPELINE_STRUCTURE_VIEW="align,genome,svg"

export APPRIS_WSERVER_OUTPUT_TYPE_SEQ="aa"

export APPRIS_WSERVER_OUTPUT_FORMAT="json"

export APPRIS_WSERVER_OUTPUT_FORMAT_SEQ="fasta"

export APPRIS_WSERVER_UCSC_URL="http://genome-euro.ucsc.edu/cgi-bin/hgTracks"

export APPRIS_WSERVER_UCSC_RENDER_URL="http://genome.ucsc.edu/cgi-bin/hgRenderTracks"

export APPRIS_WSERVER_OUTPUT_ENCODING="text/plain"

export APPRIS_WSERVER_SCRIPTS_DB_INI="${APPRIS_SCRIPTS_CONF_DIR}/apprisdb.WS.ini"

export APPRIS_NUM_PARALLEL_PROC=1

export APPRIS_WSERVER_REST_URL="http://apprisws.bioinfo.cnio.es/rest"

export APPRIS_WSERVER_REPORT_URL="http://appris.bioinfo.cnio.es/#/server/result"

# ----------------------------------------------#
# Setting up PERL LIBRARY PATH and binary files #
# ----------------------------------------------#

export APPRIS_PERL_LIB="${APPRIS_HOME}/lib/appris_perllib"

export PERL5LIB="${PERL5LIB}:${APPRIS_PERL_LIB}"