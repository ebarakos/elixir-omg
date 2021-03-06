# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Alert.Alarm do
  @moduledoc """
  Interface for raising and clearing alarms.
  """
  alias OMG.Alert.AlarmHandler

  def ethereum_client_connection_issue(node, reporter),
    do: {:ethereum_client_connection, %{node: node, reporter: reporter}}

  def boot_in_progress(node, reporter),
    do: {:boot_in_progress, %{node: node, reporter: reporter}}

  @spec set({atom(), node(), module()}) :: :ok | :duplicate
  def set(raw_alarm) do
    alarm = make_alarm(raw_alarm)
    do_raise(alarm)
  end

  def clear(raw_alarm) do
    make_alarm(raw_alarm)
    |> :alarm_handler.clear_alarm()
  end

  def clear_all do
    all_raw()
    |> Enum.each(&:alarm_handler.clear_alarm(&1))
  end

  def all do
    all_raw()
    |> Enum.map(&format_alarm/1)
  end

  defp do_raise(alarm) do
    if Enum.member?(all_raw(), alarm),
      do: :duplicate,
      else: :alarm_handler.set_alarm(alarm)
  end

  defp format_alarm({id, details}), do: %{id: id, details: details}
  defp format_alarm(alarm), do: %{id: alarm}

  defp all_raw, do: :gen_event.call(:alarm_handler, AlarmHandler, :get_alarms)

  defp make_alarm({:ethereum_client_connection, node, reporter}) do
    ethereum_client_connection_issue(node, reporter)
  end

  defp make_alarm({:boot_in_progress, node, reporter}) do
    boot_in_progress(node, reporter)
  end
end
