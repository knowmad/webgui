package WebGUI::Asset::Wobject::Folder;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2009 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use WebGUI::Definition::Asset;
extends 'WebGUI::Asset::Wobject';

aspect assetName   => ["assetName", 'Asset_Folder'];
aspect uiLevel     => 5;
aspect icon        => 'folder.gif';
aspect tableName   => 'Folder';

property visitorCacheTimeout => (
             tab             => "display",
             fieldType       => "interval",
             default         => 3600,
             uiLevel         => 8,
             label           => ["visitor cache timeout",      'Asset_Folder'],
             hoverHelp       => ["visitor cache timeout help", 'Asset_Folder'],
         );
         # TODO: This should probably be a proper "sortBy" with multiple possible fields
property sortAlphabetically => (
             fieldType       => "yesNo",
             default         => 0,
             tab             => 'display',
             label           => ['sort alphabetically',      'Asset_Folder'],
             hoverHelp       => ['sort alphabetically help', 'Asset_Folder'],
         );

#    my %optionsSortOrder = (
#        ASC     => $i18n->get( "editForm sortOrder ascending" ),
#        DESC    => $i18n->get( "editForm sortOrder descending" ),
#    );
property sortOrder => (
             tab             => 'display',
             fieldType       => "selectBox",
             #options         => \%optionsSortOrder,
             default         => "ASC",
             label           => [ "editForm sortOrder label" ,       'Asset_Folder'],
             hoverHelp       => [ "editForm sortOrder description" , 'Asset_Folder'],
         );
property templateId => (
             fieldType       => "template",
             default         => 'PBtmpl0000000000000078',
             namespace       => 'Folder',
             tab             => 'display',
             label           => ['folder template title',       'Asset_Folder'],
             hoverHelp       => ['folder template description', 'Asset_Folder'],
         );

use WebGUI::Utility;

=head1 NAME

Package WebGUI::Asset::Wobject::Folder

=head1 DESCRIPTION

Display a list of assets and sub folders just like in an operating system filesystem.

=head1 SYNOPSIS

use WebGUI::Asset::Wobject::Folder;


=head1 METHODS

These methods are available from this class:

=cut



#-------------------------------------------------------------------

=head2 getContentLastModified

Overridden to check the revision dates of children as well

=cut

sub getContentLastModified {
    my $self = shift;
    my $mtime = $self->get("revisionDate");
    foreach my $child (@{ $self->getLineage(["children"],{returnObjects=>1}) }) {
        my $child_mtime = $child->getContentLastModified;
        $mtime = $child_mtime if ($child_mtime > $mtime);
    }
    return $mtime;
}

#-------------------------------------------------------------------

=head2 getEditForm ( )

Returns the TabForm object that will be used in generating the edit page for this asset.

=cut

sub getEditForm {
	my $self = shift;
	my $tabform = $self->SUPER::getEditForm();
	my $i18n = WebGUI::International->new($self->session,"Asset_Folder");
	if ($self->get("assetId") eq "new") {
               	$tabform->getTab("properties")->whatNext(
                       	-options=>{
                               	view=>$i18n->get(823),
                      	 	"viewParent"=>$i18n->get(847)
                              	},
			-value=>"view"
			);
	}
	return $tabform;
}

#----------------------------------------------------------------------------

=head2 getTemplateVars ( )

Get the shared template vars for all views of the Folder.

=cut

sub getTemplateVars {
    my $self        = shift;
    my $vars        = $self->get;
	my $i18n        = WebGUI::International->new($self->session, 'Asset_Folder');

	$vars->{ 'addFile.label'    } = $i18n->get('add file label');
	$vars->{ 'addFile.url'      } = $self->getUrl('func=add;class=WebGUI::Asset::FilePile');
    $vars->{ canEdit            } = $self->canEdit;
    $vars->{ canAddFile         } = $self->canEdit;
    
    return $vars;
}

#-------------------------------------------------------------------

=head2 prepareView ( )

See WebGUI::Asset::prepareView() for details.

=cut

sub prepareView {
    my $self = shift;
    $self->SUPER::prepareView();
    my $template = WebGUI::Asset::Template->new($self->session, $self->get("templateId"));
    if (!$template) {
        WebGUI::Error::ObjectNotFound::Template->throw(
            error      => qq{Template not found},
            templateId => $self->get("templateId"),
            assetId    => $self->getId,
        );
    }
    $template->prepare($self->getMetaDataAsTemplateVariables);
    $self->{_viewTemplate} = $template;
}


#-------------------------------------------------------------------

=head2 purgeCache ( )

See WebGUI::Asset::purgeCache() for details.

=cut

sub purgeCache {
	my $self = shift;
	eval{$self->session->cache->delete("view_".$self->getId)};
	$self->SUPER::purgeCache;
}

#-------------------------------------------------------------------

=head2 view ( )

See WebGUI::Asset::view for details.  Generate template variables and
render the template.  Also handles caching.

=cut

sub view {
	my $self    = shift;
	
    # Use cached version for visitors
    my $cache = $self->session->cache;
	if ($self->session->user->isVisitor) {
		my $out = eval{$cache->get("view_".$self->getId)};
		return $out if $out;
	}

	my $vars    = $self->getTemplateVars;
    # TODO: Getting the children template vars should be a seperate method.
	
    my %rules   = ( returnObjects => 1);
    if ( $self->get( "sortAlphabetically" ) ) {
        $rules{ orderByClause   } = "assetData.title " . $self->get( "sortOrder" );
    }
    else {
        $rules{ orderByClause   } = "asset.lineage " . $self->get( "sortOrder" );
    }

	my $children    = $self->getLineage( ["children"], \%rules);
	foreach my $child ( @{ $children } ) {
        # TODO: Instead of this it should be using $child->getTemplateVars || $child->get
		if ( $child->isa("WebGUI::Asset::Wobject::Folder") ) {
			push @{ $vars->{ "subfolder_loop" } }, {
				id           => $child->getId,
				url          => $child->getUrl,
				title        => $child->get("title"),
				menuTitle    => $child->get("menuTitle"),
				synopsis     => $child->get("synopsis") || '',
				canView      => $child->canView(),
				"icon.small" => $child->getIcon(1),
				"icon.big"   => $child->getIcon,
			};
		} 
        else {
            my $childVars   = {
				id              => $child->getId,
				canView         => $child->canView(),
				title           => $child->get("title"),
				menuTitle       => $child->get("menuTitle"),
				synopsis        => $child->get("synopsis") || '',
				size            => WebGUI::Utility::formatBytes($child->get("assetSize")),
				"date.epoch"    => $child->get("revisionDate"),
				"icon.small"    => $child->getIcon(1),
				"icon.big"      => $child->getIcon,
				type            => $child->getName,
				url             => $child->getUrl,
				canEdit         => $child->canEdit,
				controls        => $child->getToolbar,
            };
            
            if ( $child->isa('WebGUI::Asset::File::Image') ) {
                $childVars->{ "isImage"         } = 1;
                $childVars->{ "thumbnail.url"   } = $child->getThumbnailUrl;
            }
            
            if ( $child->isa('WebGUI::Asset::File') ) {
                $childVars->{ "isFile"          } = 1;
                $childVars->{ "file.url"        } = $child->getFileUrl;
            }

			push @{ $vars->{ "file_loop" } }, $childVars;
		}
	}
	
    my $out = $self->processTemplate( $vars, undef, $self->{_viewTemplate} );

    # Update the cache
	if ($self->session->user->isVisitor) {
		eval{$cache->set("view_".$self->getId, $out, $self->get("visitorCacheTimeout"))};
	}

    return $out;
}


#-------------------------------------------------------------------

=head2 www_view ( )

See WebGUI::Asset::Wobject::www_view() for details.

=cut

sub www_view {
	my $self = shift;
	$self->session->http->setCacheControl($self->get("visitorCacheTimeout")) if ($self->session->user->isVisitor);
	$self->SUPER::www_view(@_);
}


1;

