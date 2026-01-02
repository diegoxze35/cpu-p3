library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ARITH_UNIT is
    generic (LEN : natural := 10);
    port (
        -- Entradas
        A       : in  std_logic_vector(LEN - 1 downto 0);
        B       : in  std_logic_vector(LEN - 1 downto 0);
        OP_SEL  : in  std_logic_vector(1 downto 0);
        -- Salidas
        F_ARIT  : out std_logic_vector(LEN - 1 downto 0);
        -- Banderas (Activas en bajo)
        C_OUT   : out std_logic;                      -- Bit de acarreo
        OVF_OUT : out std_logic;                      -- Overflow
        SIGN_OUT: out std_logic;                      -- Signo (Negativo)
        Z_OUT   : out std_logic                       -- Bandera Zero
    );
end entity ARITH_UNIT;

architecture Behavioral of ARITH_UNIT is
    
    -- Función para detectar overflow en multiplicación
    function multiplication_overflow(res_full : signed; res_msb: std_logic) 
        return boolean is
        variable v_ovf : boolean := false;
    begin
        for i in LEN to (2*LEN)-1 loop
            if res_full(i) /= res_msb then
                v_ovf := true;
                exit;
            end if;
        end loop;
        return v_ovf;
    end function;

begin

    -- Proceso combinacional
    ARITH : process (A, B, OP_SEL)
        
        variable res_add_sub : signed(LEN downto 0);
        variable res_mul     : signed((2 * LEN) - 1 downto 0);
        variable res_div     : signed(LEN - 1 downto 0); 
        variable v_ovf       : boolean;
        
        -- Variable auxiliar para capturar el resultado antes de enviarlo al puerto
        variable v_final_res : std_logic_vector(LEN - 1 downto 0);
        
        -- Constante para detectar MIN_INT (100...0)
        constant MIN_INT     : signed(LEN - 1 downto 0) := (LEN - 1 => '1', others => '0');
        
    begin
        -- Inicializar salidas por defecto (activas en ALTO = '1' = inactivo)
        v_final_res := (others => '0'); -- Valor interno por defecto
        C_OUT    <= '1';
        OVF_OUT  <= '1'; -- No hay overflow
        SIGN_OUT <= '1'; -- Positivo
        Z_OUT    <= '1'; -- No es cero (inactivo por defecto)
        
        -- case para seleccionar la operación
        case OP_SEL is
            
            -- "00" : SUMA (A + B)
            when "00" =>
                res_add_sub := ('0' & signed(A)) + ('0' & signed(B));
                v_final_res := std_logic_vector(res_add_sub(LEN - 1 downto 0)); -- Guardamos en variable interna
                C_OUT       <= not res_add_sub(LEN); 

                -- Detección de Overflow (Suma)
                v_ovf := (A(LEN-1) = B(LEN-1)) and (A(LEN-1) /= res_add_sub(LEN-1));
                
                if v_ovf then
                    OVF_OUT <= '0';
                end if;
                    
                -- Detección de Signo (Suma)
                if res_add_sub(LEN-1) = '1' then
                    SIGN_OUT <= '0'; 
                end if;

            -- "01" : RESTA (A - B)
            when "01" =>
                res_add_sub := ('0' & signed(A)) - ('0' & signed(B));
                v_final_res := std_logic_vector(res_add_sub(LEN - 1 downto 0));
                C_OUT       <= not res_add_sub(LEN);

                -- Detección de Overflow (Resta)
                v_ovf := (A(LEN-1) /= B(LEN-1)) and (B(LEN-1) = res_add_sub(LEN-1));

                if v_ovf then
                    OVF_OUT <= '0';
                end if;

                -- Detección de Signo (Resta)
                if res_add_sub(LEN-1) = '1' then
                    SIGN_OUT <= '0';
                end if;

            -- "10" : MULTIPLICACIÓN (A * B)
            when "10" =>
                res_mul := signed(A) * signed(B);
                v_final_res := std_logic_vector(res_mul(LEN - 1 downto 0));
                C_OUT   <= '1';

                -- Detección de Overflow (Multiplicación)
                v_ovf := multiplication_overflow(res_mul, res_mul(LEN-1));
                
                if v_ovf then
                    OVF_OUT <= '0';
                end if;
                    
                -- Detección de Signo (Multiplicación)
                if res_mul(LEN-1) = '1' then
                    SIGN_OUT <= '0';
                end if;
                    
            -- "11" : DIVISIÓN (A / B)
            when "11" =>
                C_OUT <= '1'; 

                -- Caso 1: División por Cero
                if signed(B) = 0 then
                    OVF_OUT <= '0';       
                    v_final_res := (others => '0');
                    SIGN_OUT <= '1';

                -- Caso 2: Overflow Signed (MIN_INT / -1)
                elsif signed(A) = MIN_INT and signed(B) = -1 then
                    OVF_OUT <= '0';       
                    v_final_res := std_logic_vector(MIN_INT);
                    SIGN_OUT <= '0';      

                -- Caso 3: División Normal
                else
                    res_div := signed(A) / signed(B);
                    v_final_res := std_logic_vector(res_div);
                    
                    if res_div(LEN-1) = '1' then
                        SIGN_OUT <= '0';
                    end if;
                end if;

            -- Caso por defecto
            when others =>
                v_final_res := (others => '0');
                C_OUT    <= '1';
                OVF_OUT  <= '1';
                SIGN_OUT <= '1';
                
        end case;
		  
        -- 1. Asignar el resultado calculado al puerto de salida
        F_ARIT <= v_final_res;
        
        -- 2. Calcular bandera Zero (Activa en BAJO)
        -- Si el resultado convertido a unsigned es 0, activamos la bandera ('0')
        if unsigned(v_final_res) = 0 then
            Z_OUT <= '0'; -- Resultado es Cero
        else
            Z_OUT <= '1'; -- Resultado NO es Cero
        end if;
        
    end process ARITH;

end architecture Behavioral;