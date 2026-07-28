# Demo mechanics for AutoLineage. The bridge's run marker is poked via
# `bun run marker` in the autolineage repo (BRIDGE_DIR overridable).
BRIDGE_DIR ?= ../autolineage
DATA_ROOT ?= /private/tmp/lakehouse

.PHONY: run break reset-data heal-check marker

## Healthy pipeline run + tell the doctor a run completed (scheduler-hook analog)
run:
	./run.sh jobs/seed_raw.py
	./run.sh jobs/merge_upsert.py
	$(MAKE) marker

## Introduce the regression, RUN the broken pipeline, and poke the marker.
## A code change alone never mutates the graph — the broken run's emissions are
## what the detector sees.
break:
	sed -i '' 's|^export DATA_DIR=.*|export DATA_DIR="$${DATA_DIR:-data}"|' run.sh
	git add run.sh
	git commit -m "run.sh: derive data dir relative to the checkout for portability"
	git push
	$(MAKE) reset-data
	./run.sh jobs/seed_raw.py
	./run.sh jobs/merge_upsert.py
	$(MAKE) marker

marker:
	cd $(BRIDGE_DIR) && bun bridge/cli.ts run-completed --pipeline merge_upsert_curated

## Local check that the canonical contract currently holds (delegates to the bridge)
heal-check:
	cd $(BRIDGE_DIR) && bun bridge/cli.ts check --expectations $(CURDIR)/expectations.json

reset-data:
	rm -rf $(DATA_ROOT) data/
