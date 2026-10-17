# BCJRFormer RTL architecture review

10 October 2026. Derived from the latest architecture discussion and current local RTL/specification.

Open BCJRFormer-RTL-architecture.html in a browser. Select a box to inspect child blocks, internal scheduled operations and all RTL interfaces. Select a wire for its signal contract. Use the last tab to search all connections and read the original SystemVerilog channel/descriptor declarations. The drawio file has five editable diagram pages. SVG views and a PNG overview are included.

IcePanel model: BCJRFormer ASIC — RTL architecture. Created 59 objects including the project system, architecture groupings, controllers/services, 18 native memory banks, host and clock/reset. Created 98 connections (including clock/reset and internal bank decomposition). The 18 storage-decomposition edges are not extra external RTL ports. An ADR records exact SV interfaces and implementation internals. IcePanel tools do not expose creation/layout of diagram views; no native IcePanel diagram was created.

Solid green means implemented behavioral/protocol RTL; dashed blue means planned RTL or an architectural grouping. Groupings are not new physical wrappers. command_switch/arithmetic_switch/memory_fabric use transaction_router; parameter_mem/scratch_mem use memory_adapter. Stages exchange tensors through logical memory, not stage-to-stage RTL tensor channels. Stage dependency arrows in the overview show this logical flow.

Numerical formats, model dimensions, capacity selection, physical SRAM macros, frequency and technology remain provisional/unselected. Arithmetic and processing/controller RTL remain planned. Current protocol/memory verification limits are documented in RTL-PROTOCOL-CHECKPOINT.md and RTL-MEMORY-CHECKPOINT.md. This diagram creation did not change processing RTL.

Checks: JavaScript syntax; complete endpoint references; 18 banks; 13 memory clients; 98 recorded successful IcePanel connection creations. Fabric read-back confirmed 13 client links plus both adapters and reset. SVG overview rendered and visually reviewed.

Regenerate local diagrams with: node rtl/build-architecture-review.cjs
