package WebGUI::i18n::English::TransactionLog;

our $I18N = {
	'cancel error' => {
		message => q|An error has occurred while canceling the recurring transaction. Please contact the admin. Error: |,
		lastUpdated => 0,
		context => q|An error message that's shown when a subscription cancelation fails.|
	},

	'cannot cancel' => {
		message => q|You cannot cancel a non recurring transaction|,
		lastUpdated => 0,
		context => q|An error message that's shown when an attempt is made to cancel a non recurring transaction.|
	},

	'help purchase history template body' => {
		message => q|The following template variables are available in this template:<br>
<br>
<b>errorMessage</b><br>
A message with an error concerning the cancelation of recuuring payment.<br>
<br>
<b>historyLoop</b><br>
A loop containing the transactions in the transaction history. Within this loop these variables are also available:<br>
<blockquote>
	<b>amount</b><br>
	The total amount of this transaction.<br>
	<br>
	<b>recurring</b><br>
	A boolean that indicates wheter this is a recurring transaction or not.<br>
	<br>
	<b>canCancel</b><br>
	A boolean value indicating wheter it's possible to cancel this transaction. This is only teh case with recurring payments that haven't been canceled yet.<br>
	<br>
	<b>cancelUrl</b><br>
	The URL to visit when you ant to cancel this recurring transaction.<br>
	<br>
	<b>initDate</b><br>
	The date the transaction was initialized.<br>
	<br>
	<b>completionDate</b><br>
	The date on which the transaction has been confirmed.<br>
	<br>
	<b>status</b><br>
	The status for this transaction.<br>
	<br>
	<b>lastPayedTerm</b><br>
	The most recent term that has been payed. This is an integer.<br>
	<br>
	<b>gateway</b><br>
	The payment gateway that was used.<br>
	<br>
	<b>gatewayId</b><br>
	The ID that is assigned to this transaction by the payment gateway.<br>
	<br>
	<b>transactionId</b><br>
	The internal ID that is assigned to this transaction by WebGUI.<br>
	<br>
	<b>userId</b><br>
	The internal WebGUI user ID of the user that performed this transaction.<br>
	<br>
	<b>itemLoop</b>
	This loop contains all items the transaction consists of. These variables are available:<br>
	<blockquote>
		<b>amount</b><br>
		The amount of this item.<br>
		<br>
		<b>itemName</b><br>
		The name of this item.<br>
		<br>
		<b>itemId</b><br>
		The internal WebGUI ID tied to this item.<br>
		<br>
		<b>itemType</b><br>
		The type that this item's of.<br>
		<br>
		<b>quantity</b><br>
		The quantity in which this item is bought.<br>
	</blockquote>
</blockquote>|,
		lastUpdated => 0,
		context => q|The body of the help page of the purchase history template.|
	},
	'help purchase history template title' => {
		message => q|View purchase history template|,
		lastUpdated => 0,
		context => q|The title of the help page of the purchase history template.|
	},

}
