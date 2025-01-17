use crate::cli::{Cli, RelayChainCli};
use codec::Encode;
use common_primitives::node::Block;
use cumulus_client_cli::generate_genesis_block;
use cumulus_primitives_core::ParaId;
use frequency_service::chain_spec;
use log::info;
use sc_cli::SubstrateCli;
use sp_core::hexdisplay::HexDisplay;
use sp_runtime::traits::{AccountIdConversion, Block as BlockT};

pub fn run_as_parachain(cli: Cli) -> sc_service::Result<(), sc_cli::Error> {
	let runner = cli.create_runner(&cli.run.normalize())?;
	runner.run_node_until_exit(|config| async move {
		let para_id = chain_spec::Extensions::try_get(&*config.chain_spec)
			.map(|e| e.para_id)
			.ok_or("Could not find parachain ID in chain-spec.")?;
		let id = ParaId::from(para_id);

		let parachain_account =
			AccountIdConversion::<polkadot_primitives::AccountId>::into_account_truncating(&id);

		let state_version = Cli::native_runtime_version(&config.chain_spec).state_version();
		let block: Block = generate_genesis_block(&*config.chain_spec, state_version)
			.map_err(|e| format!("{:?}", e))?;
		let genesis_state = format!("0x{:?}", HexDisplay::from(&block.header().encode()));

		info!("Parachain id: {:?}", id);
		info!("Parachain Account: {}", parachain_account);
		info!("Parachain genesis state: {}", genesis_state);
		info!("Is collating: {}", if config.role.is_authority() { "yes" } else { "no" });

		let tokio_handle = config.tokio_handle.clone();
		let polkadot_cli = RelayChainCli::new(
			&config,
			[RelayChainCli::executable_name()].iter().chain(cli.relay_chain_args.iter()),
		);
		let polkadot_config =
			SubstrateCli::create_configuration(&polkadot_cli, &polkadot_cli, tokio_handle)
				.map_err(|err| format!("Relay chain argument error: {}", err))?;

		let collator_options = cli.run.collator_options();
		let hwbench = if !cli.no_hardware_benchmarks {
			config.database.path().map(|database_path| {
				let _ = std::fs::create_dir_all(&database_path);
				sc_sysinfo::gather_hwbench(Some(database_path))
			})
		} else {
			None
		};
		return frequency_service::service::start_parachain_node(
			config,
			polkadot_config,
			collator_options,
			id,
			hwbench,
		)
		.await
		.map(|r| r.0)
		.map_err(Into::into)
	})
}
