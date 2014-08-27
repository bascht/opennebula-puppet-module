require 'rexml/document'
require 'tempfile'
require 'erb'
require 'puppet/util/opennebula'

Puppet::Type.type(:onetemplate).provide(:onetemplate) do
  desc "onetemplate provider"
  extend Puppet::Util::Opennebula::CLI
  extend Puppet::Util::Opennebula::Properties

  commands :onetemplate => "onetemplate"

  mk_resource_methods

  property_map :cpu     => "VMTEMPLATE/TEMPLATE/CPU",
    :memory             => "VMTEMPLATE/TEMPLATE/MEMORY",
    :vcpu               => "VMTEMPLATE/TEMPLATE/VCPU",
    :os_kernel          => "VMTEMPLATE/TEMPLATE/OS/KERNEL",
    :os_initrd          => "VMTEMPLATE/TEMPLATE/OS/INITRD",
    :os_arch            => "VMTEMPLATE/TEMPLATE/OS/ARCH",
    :os_root            => "VMTEMPLATE/TEMPLATE/OS/ROOT",
    :os_kernel_cmd      => "VMTEMPLATE/TEMPLATE/OS/KERNELCMD",
    :os_bootloader      => "VMTEMPLATE/TEMPLATE/OS/BOOTLOADER",
    :os_boot            => "VMTEMPLATE/TEMPLATE/OS/BOOT",
    :acpi               => "VMTEMPLATE/TEMPLATE/FEATURES/ACPI",
    :pae                => "VMTEMPLATE/TEMPLATE/FEATURES/PAE",
    :pci_bridge         => "VMTEMPLATE/TEMPLATE/FEATURES/PCI_BRIDGE",
    :disks              => "VMTEMPLATE/TEMPLATE/DISK/IMAGE",
    :nics               => "VMTEMPLATE/TEMPLATE/NIC/NETWORK",
    :nic_model          => "VMTEMPLATE/TEMPLATE/NIC/MODEL",
    :graphics_type      => "VMTEMPLATE/TEMPLATE/GRAPHICS/TYPE",
    :graphics_listen    => "VMTEMPLATE/TEMPLATE/GRAPHICS/LISTEN",
    :graphics_port      => "VMTEMPLATE/TEMPLATE/GRAPHICS/PORT",
    :graphics_passwd    => "VMTEMPLATE/TEMPLATE/GRAPHICS/PASSWORD",
    :graphics_keymap    => "VMTEMPLATE/TEMPLATE/GRAPHICS/KEYMAP",
    :context_ssh        => "VMTEMPLATE/TEMPLATE/CONTEXT/SSH",
    :context_ssh_pubkey => "VMTEMPLATE/TEMPLATE/CONTEXT/SSH_PUBLIC_KEY",
    :context_network    => "VMTEMPLATE/TEMPLATE/CONTEXT/NETWORK",
    :context_onegate    => "VMTEMPLATE/TEMPLATE/CONTEXT/ONEGATE",
    :context_files      => "VMTEMPLATE/TEMPLATE/CONTEXT/FILES_DS"

  # Create a VM template with onetemplate by passing in a temporary template definition file.
  def create
    file = Tempfile.new("onetemplate-#{resource[:name]}")
    template = ERB.new <<-EOF
<TEMPLATE>
  <NAME><%=   resource[:name]   %></NAME>
  <MEMORY><%= resource[:memory] %></MEMORY>
  <CPU><%=    resource[:cpu]    %></CPU>
  <VCPU><%=   resource[:vcpu]   %></VCPU>

  <OS>
<% if resource[:os_kernel]     %>    <KERNEL><%=     resource[:os_kernel]     %></KERNEL><% end %>
<% if resource[:os_initrd]     %>    <INITRD><%=     resource[:os_initrd]     %></INITRD><% end %>
<% if resource[:os_arch]       %>    <ARCH><%=       resource[:os_arch]       %></ARCH><% end %>
<% if resource[:os_root]       %>    <ROOT><%=       resource[:os_root]       %></ROOT><% end %>
<% if resource[:os_kernel_cmd] %>    <KERNEL_CMD><%= resource[:os_kernel_cmd] %></KERNEL_CMD><% end %>
<% if resource[:os_bootloader] %>    <BOOTLOADER><%= resource[:os_bootloader] %></BOOTLOADER><% end %>
<% if resource[:os_boot]       %>    <BOOT><%=       resource[:os_boot]       %></BOOT><% end %>
  </OS>

  <DISK>
<% resource[:disks].each do |disk| %>
    <IMAGE><%= disk %></IMAGE>
<% end %>
  </DISK>
<% resource[:nics].each do |nic| %>
  <NIC>
    <% if resource[:nic_model] %><MODEL><%= resource[:nic_model] %></MODEL><% end %>
    <NETWORK><%= nic %></NETWORK>
  </NIC>
<% end %>

  <GRAPHICS>
<% if resource[:graphics_type]   %><TYPE><%=   resource[:graphics_type]   %></TYPE><% end %>
<% if resource[:graphics_listen] %><LISTEN><%= resource[:graphics_listen] %></LISTEN><% end %>
<% if resource[:graphics_port]   %><PORT><%=   resource[:graphics_port]   %></PORT><% end %>
<% if resource[:graphics_passwd] %><PASSWD><%= resource[:graphics_passwd] %></PASSWD><% end %>
<% if resource[:graphics_keymap] %><KEYMAP><%= resource[:graphics_keymap] %></KEYMAP><% end %>
  </GRAPHICS>
  <FEATURES>
<% if resource[:acpi] %><ACPI><%= resource[:acpi] %></ACPI><% end %>
<% if resource[:pae]  %><PAE><%=  resource[:pae]  %></PAE><%  end %>
  </FEATURES>
  <CONTEXT>
<% if resource[:context_network] %><NETWORK><%= resource[:context_network] %></NETWORK><% end %>
<% if resource[:context_files] %>
    <FILES_DS><% resource[:context_files].each do |context_file| %>$FILE[IMAGE="<%= context_file %>"] <% end %></FILES_DS>
<% end %>
<% if resource[:context] %>
<% resource[:context].each do |key, value| %>
   <<%= key %>><%= value %></<%= key %>>
<% end %>
<% end %>
<% if resource[:context_ssh_pubkey] %><SSH_PUBLIC_KEY><%= resource[:context_ssh_pubkey] %></SSH_PUBLIC_KEY><% end %>
  </CONTEXT>
</TEMPLATE>
EOF

    tempfile = template.result(binding)
    file.write(tempfile)
    file.close
    self.debug "Creating template using #{tempfile}"
    output = "onetemplate create #{file.path} ", self.class.login
    `#{output}`
    file.delete
    @property_hash[:ensure] = :present
  end

  # Destroy a VM using onevm delete
  def destroy
    output = "onetemplate delete #{resource[:name]} ", self.class.login
    `#{output}`
    @property_hash.clear
  end

  # Check if a VM exists by scanning the onevm list
  def exists?
    @property_hash[:ensure] == :present
  end

  # Return the full hash of all existing onevm resources
  def self.instances
    output = "onetemplate list -x ", login
    REXML::Document.new(`#{output}`).elements.collect("VMTEMPLATE_POOL/VMTEMPLATE") do |template|
      elements = template.elements
      new(
        :name                      => elements["NAME"].text,
        :ensure                    => :present,
        :acpi                      => (elements["TEMPLATE/FEATURES/ACPI"].text unless elements["TEMPLATE/FEATURES/ACPI"].nil?),
        :context                   => (elements["TEMPLATE/CONTEXT"].text unless elements["TEMPLATE/CONTEXT"].nil?),
        :context_files             => (elements["TEMPLATE/CONTEXT/FILES_DS"].text.to_a unless elements["TEMPLATE/CONTEXT/FILES_DS"].nil?),
        :context_network           => (elements["TEMPLATE/CONTEXT/NETWORK"].text unless elements["TEMPLATE/CONTEXT/NETWORK"].nil?),
        :context_onegate           => (elements["TEMPLATE/CONTEXT/ONEGATE"].text unless elements["TEMPLATE/CONTEXT/ONEGATE"].nil?),
        :context_placement_cluster => (elements["TEMPLATE/CONTEXT/PLACEMENT/CLUSTER"].text unless elements["TEMPLATE/CONTEXT/PLACEMENT/CLUSTER"].nil?),
        :context_placement_host    => (elements["TEMPLATE/CONTEXT/PLACEMENT/HOST"].text unless elements["TEMPLATE/CONTEXT/PLACEMENT/HOST"].nil?),
        :context_policy            => (elements["TEMPLATE/CONTEXT/POLICY"].text unless elements["TEMPLATE/CONTEXT/POLICY"].nil?),
        :context_ssh               => (elements["TEMPLATE/CONTEXT/SSH"].text unless elements["TEMPLATE/CONTEXT/SSH"].nil?),
        :context_ssh_pubkey        => (elements["TEMPLATE/CONTEXT/SSH_PUBLIC_KEY"].text unless elements["TEMPLATE/CONTEXT/SSH_PUBLIC_KEY"].nil?),
        :context_variables         => (elements["TEMPLATE/CONTEXT/VARIABLES"].text unless elements["TEMPLATE/CONTEXT/VARIABLES"].nil?),
        :cpu                       => (elements["TEMPLATE/CPU"].text unless elements["TEMPLATE/CPU"].nil?),
        :disks                     => (elements["TEMPLATE/DISK/IMAGE"].text.to_a unless elements["TEMPLATE/DISK/IMAGE"].nil?),
        :graphics_keymap           => (elements["TEMPLATE/GRAPHICS/KEYMAP"].text unless elements["TEMPLATE/GRAPHICS/KEYMAP"].nil?),
        :graphics_listen           => (elements["TEMPLATE/GRAPHICS/LISTEN"].text unless elements["TEMPLATE/GRAPHICS/LISTEN"].nil?),
        :graphics_passwd           => (elements["TEMPLATE/GRAPHICS/PASSWORD"].text unless elements["TEMPLATE/GRAPHICS/PASSWORD"].nil?),
        :graphics_port             => (elements["TEMPLATE/GRAPHICS/PORT"].text unless elements["TEMPLATE/GRAPHICS/PORT"].nil?),
        :graphics_type             => (elements["TEMPLATE/GRAPHICS/TYPE"].text unless elements["TEMPLATE/GRAPHICS/TYPE"].nil?),
        :memory                    => (elements["TEMPLATE/MEMORY"].text unless elements["TEMPLATE/MEMORY"].nil?),
        :nic_model                 => (elements["TEMPLATE/NIC/MODEL"].text unless elements["TEMPLATE/NIC/MODEL"].nil?),
        :nics                      => (elements["TEMPLATE/NIC/NETWORK"].text.to_a unless elements["TEMPLATE/NIC/NETWORK"].nil?),
        :os_arch                   => (elements["TEMPLATE/OK/ARCH"].text unless elements["TEMPLATE/OK/ARCH"].nil?),
        :os_boot                   => (elements["TEMPLATE/OK/BOOT"].text unless elements["TEMPLATE/OK/BOOT"].nil?),
        :os_bootloader             => (elements["TEMPLATE/OK/BOOTLOADER"].text unless elements["TEMPLATE/OK/BOOTLOADER"].nil?),
        :os_initrd                 => (elements["TEMPLATE/OK/INITRD"].text unless elements["TEMPLATE/OK/INITRD"].nil?),
        :os_kernel                 => (elements["TEMPLATE/OK/KERNEL"].text unless elements["TEMPLATE/OK/KERNEL"].nil?),
        :os_kernel_cmd             => (elements["TEMPLATE/OK/KERNELCMD"].text unless elements["TEMPLATE/OK/KERNELCMD"].nil?),
        :os_root                   => (elements["TEMPLATE/OK/ROOT"].text unless elements["TEMPLATE/OK/ROOT"].nil?),
        :pae                       => (elements["TEMPLATE/FEATURES/PAE"].text unless elements["TEMPLATE/FEATURES/PAE"].nil?),
        :pci_bridge                => (elements["TEMPLATE/FEATURES/PCI_BRIDGE"].text unless elements["TEMPLATE/FEATURES/PCI_BRIDGE"].nil?),
        :vcpu                      => (elements["TEMPLATE/VCPU"].text unless elements["TEMPLATE/VCPU"].nil?)
      )
    end
  end

  def self.prefetch(resources)
    templates = instances
    resources.keys.each do |name|
      if provider = templates.find{ |template| template.name == name }
        resources[name].provider = provider
      end
    end
  end
end
