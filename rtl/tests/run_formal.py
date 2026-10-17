from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root/'.tools'))
import yowasp_yosys
clients = int(sys.argv[1]) if len(sys.argv)>1 else 3
if clients not in (1,2,3,5,13):
    raise SystemExit('Supported review cases: 1,2,3,5,13 clients')
# Yosys resolves workspace files through its WASI runtime mapping.
sys.argv = ['yowasp-yosys', '-p',
    'read_verilog -sv -formal rtl/protocol/transaction_router.sv rtl/tests/router_formal.sv; '
    f'chparam -set CLIENTS {clients} router_formal; '
    'prep -top router_formal -flatten; async2sync; chformal -lower; '
    'sat -seq 24 -prove-asserts -set-assumes -verify']
sys.exit(yowasp_yosys._run_yosys_argv())
