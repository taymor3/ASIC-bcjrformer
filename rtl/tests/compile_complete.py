from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'rtl/.tools'))
from pyslang.driver import Driver
sources=[root/p for p in (root/'rtl/protocol/files.f').read_text().splitlines() if p.strip()]
driver=Driver();driver.addStandardArgs()
args='slang --top complete_elaboration '+ ' '.join('"'+str(p)+'"' for p in sources+[root/'rtl/tests/complete_elaboration.sv'])
if not driver.parseCommandLine(args) or not driver.processOptions() or not driver.parseAllSources():
    driver.reportDiagnostics(False);sys.exit(1)
compilation=driver.createCompilation();driver.reportCompilation(compilation,False)
sys.exit(0 if driver.reportDiagnostics(False) else 1)
