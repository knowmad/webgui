package WebGUI::Help::Commerce;

our $HELP = {
	'commerce manage' => {
		title => 'help manage commerce title',
		body => 'help manage commerce body',
		related => [
		]
	},

	'list pending transactions' => {
		title => 'help manage pending transactions title',
		body => 'help manage pending transactions body',
		related => [
		]
	},

	'cancel template' => {
		title => 'help cancel checkout template title',
		body => 'help cancel checkout template body',
		related => [
			{
				tag => 'template language',
				namespace => 'WebGUI'
			},
			{
				tag => 'templates manage',
				namespace => 'WebGUI'
			}
		]
	},

	'confirm template' => {
		title => 'help checkout confirm template title',
		body => 'help checkout confirm template body',
		related => [
			{
				tag => 'template language',
				namespace => 'WebGUI'
			},
			{
				tag => 'templates manage',
				namespace => 'WebGUI'
			}
		],
	},

	'error template' => {
		title => 'help checkout error template title',
		body => 'help checkout error template body',
		related => [
			{
				tag => 'template language',
				namespace => 'WebGUI'
			},
			{
				tag => 'templates manage',
				namespace => 'WebGUI'
			}
		]
	},
};

1;
