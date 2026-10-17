from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.tools'))
from pyslang.driver import Driver

sources = [root/'interfaces/bcjrformer_contract_pkg.sv',
           root/'interfaces/bcjrformer_channels.sv',
           root/'interfaces/bcjrformer_ports.svh',
           root/'protocol/transaction_router.sv',
           root/'protocol/command_switch.sv',
           root/'protocol/arithmetic_switch.sv',
           root/'protocol/memory_fabric.sv',
           root/'memory/memory_adapter.sv',
           root/'memory/parameter_mem.sv',
           root/'memory/scratch_mem.sv',
           root/'control/core_ctrl.sv',
           root/'control/embedding_ctrl.sv',
           root/'control/position_sequencer.sv',
           root/'control/encoder_ctrl.sv',
           root/'control/layer_ctrl.sv',
           root/'control/attention_ctrl.sv',
           root/'control/projection_loop.sv',
           root/'control/qkv_ctrl.sv',
           root/'control/output_projection_ctrl.sv',
           root/'tests/protocol_elaboration.sv',
           root/'tests/memory_formal.sv']
sources = [root.parent/p for p in (root/'protocol/files.f').read_text().splitlines()] + [
    root/'interfaces/bcjrformer_ports.svh',root/'tests/protocol_elaboration.sv',root/'tests/memory_formal.sv']
driver = Driver()
driver.addStandardArgs()
args = 'slang --top protocol_elaboration ' + ' '.join('"'+str(p)+'"' for p in sources)
if not driver.parseCommandLine(args) or not driver.processOptions() or not driver.parseAllSources():
    driver.reportDiagnostics(False)
    sys.exit(1)
compilation = driver.createCompilation()
driver.reportCompilation(compilation, False)
sys.exit(0 if driver.reportDiagnostics(False) else 1)
