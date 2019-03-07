# Copyright 2019 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.Challenger.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.State.Transaction.Signed
  alias OMG.API.TestHelper
  alias OMG.API.Utxo
  alias OMG.Watcher.Challenger.Core
  alias OMG.Watcher.ExitProcessor.ExitInfo

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  defp create_block_with(blknum, txs) do
    %Block{
      number: blknum,
      transactions: Enum.map(txs, & &1.signed_tx_bytes)
    }
  end

  defp assert_sig_belongs_to(sig, %Signed{raw_tx: raw_tx}, expected_owner) do
    {:ok, signer_addr} =
      raw_tx
      |> Transaction.hash()
      |> Crypto.recover_address(sig)

    assert expected_owner.addr == signer_addr
  end

  @tag fixtures: [:alice, :bob]
  test "creates a challenge for an exit; provides utxo position of non-zero amount", %{alice: alice, bob: bob} do
    # transactions spending one of utxos from above transaction
    tx_spending_1st_utxo =
      TestHelper.create_signed([{0, 0, 0, alice}, {1000, 0, 0, alice}], @eth, [{bob, 50}, {alice, 50}])

    tx_spending_2nd_utxo =
      TestHelper.create_signed([{1000, 0, 1, bob}, {0, 0, 0, alice}], @eth, [{alice, 50}, {bob, 50}])

    spending_block = create_block_with(2000, [tx_spending_1st_utxo, tx_spending_2nd_utxo])

    # Assert 1st spend challenge
    expected_txbytes = tx_spending_1st_utxo.raw_tx |> Transaction.encode()

    assert %{
             exit_id: 424_242_424_242_424_242_424_242_424_242,
             input_index: 1,
             txbytes: ^expected_txbytes,
             sig: alice_signature
           } =
             Core.create_challenge(
               %ExitInfo{owner: alice.addr},
               spending_block,
               Utxo.position(1000, 0, 0),
               424_242_424_242_424_242_424_242_424_242
             )

    assert_sig_belongs_to(alice_signature, tx_spending_1st_utxo, alice)

    # Assert 2nd spend challenge
    expected_txbytes = tx_spending_2nd_utxo.raw_tx |> Transaction.encode()

    assert %{
             exit_id: 333,
             input_index: 0,
             txbytes: ^expected_txbytes,
             sig: bob_signature
           } = Core.create_challenge(%ExitInfo{owner: bob.addr}, spending_block, Utxo.position(1000, 0, 1), 333)

    assert_sig_belongs_to(bob_signature, tx_spending_2nd_utxo, bob)
  end

  test "not spent or not existed utxo should be not challengeable" do
    exit_info = %{owner: "alice"}
    assert {:ok, 1000, %ExitInfo{owner: "alice"}} = Core.ensure_challengeable({:ok, 1000}, {:ok, {{}, exit_info}})

    assert {:error, :utxo_not_spent} = Core.ensure_challengeable({:ok, :not_found}, {:ok, {{}, exit_info}})
    assert {:error, :exit_not_found} = Core.ensure_challengeable({:ok, 1000}, {:ok, :not_found})

    assert {:error, :db_other_error1} = Core.ensure_challengeable({:error, :db_other_error1}, {:ok, {{}, exit_info}})
    assert {:error, :db_other_error2} = Core.ensure_challengeable({:ok, 1000}, {:error, :db_other_error2})
  end
end
